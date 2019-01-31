zone: { lib, name, nodes, pkgs, resources, ... }: with lib;

let
  address = ip: ip + ":4010:4011";
  hasWitnessTag = node: elem "witness" node.config.system.nixos.tags;
in

{
  ##
  # `map` to make additional SGs easier to add and SG list more readable
  deployment.ec2.securityGroupIds = map (x: resources.ec2SecurityGroups."cluster-${x}-sg".name ) (
    [ "educator-api-private" "witness-public" ]
  );

  deployment.ec2.subnetId = lib.mkForce resources.vpcSubnets."${zone}-subnet";

  networking.firewall.allowedTCPPorts = [
    4010 4011   # Witness ZMQ API
    4030        # Witness HTTP Wallet API
    4040        # Educator HTTP API
  ];

  services.postgresql = {
    enable = true;
    package = pkgs.postgresql_9_6;
  };

  services.disciplina = let
    config-key = "alpha";

  in rec {
    enable = true;
    type = "educator";


    config."${config-key}" = rec {
      witness = rec {
        appDir.param = {
          paramType = "specific";
          specific.path = "/var/lib/disciplina-${type}";
        };
        db = {
          path = "${appDir.param.specific.path}/witness.db";
          clean = false;
        };
        api.maybe = {
          maybeType = "just";
          just.addr = "0.0.0.0:4030";
        };
        keys.params = {
          paramsType = "basic";
          basic = {
            path = "${appDir.param.specific.path}/witness.key";
            genNew = true;
          };
        };
      };

      educator = {
        publishing.period = "30s";
        db = {
          connString = "postgresql://disciplina@/disciplina";
          connNum = 4;
          maxPending = 100;
        };

        keys.keyParams = {
          path = "${witness.appDir.param.specific.path}/educator.key";
          genNew = true;
        };

        api = {
          serverParams.addr = "0.0.0.0:4040";
          botConfig.params = {
            paramsType = "enabled";
            enabled = {
              operationsDelay = "3s";
              seed = "super secure"; # this is not sensitive data (https://serokell.slack.com/archives/CC92X27D3/p1542652947445200)
            };
          };
          studentAPINoAuth.enabled = false;
          educatorAPINoAuth.enabled = false;
        };
      };
    };

    args = {
      inherit config-key;
      bind = address "*";
      peer = map (node: address node.config.networking.privateIPv4)
        (attrValues (filterAttrs (name2: node: name != name2 && hasWitnessTag node) nodes));
    };

    requires = [ "postgresql.service" ];
    serviceConfig = {
      ExecStartPre =
        let
          psql = args:
            "${pkgs.sudo}/bin/sudo -u postgres ${pkgs.postgresql}/bin/psql " + args;
          dbUserInitScript = pkgs.writeText "educator-db-user.sql" ''
            DO $$
            BEGIN
               IF NOT EXISTS
                 (SELECT FROM pg_catalog.pg_roles WHERE rolname = 'disciplina')
               THEN
                 CREATE ROLE disciplina LOGIN;
               END IF;
            END $$;
          '';
          dbInitScript = pkgs.writeText "educator-db.sql" ''
            CREATE DATABASE disciplina OWNER disciplina;
          '';
        in [
          "!${psql "-v ON_ERROR_STOP -f ${dbUserInitScript}"}"
          "!${psql "-f ${dbInitScript}"}"  # ignores errors
        ];
    };
  };

  system.nixos.tags = [ "educator" "witness" ];
}
