env: n: { lib, name, nodes, pkgs, resources, ... }: with lib;

let
  keys = config.dscp.keys;
  address = ip: ip + ":4010:4011";
  hasWitnessTag = node: elem "witness" node.config.system.nixos.tags;
  hasInternalTag = node: elem "internal" node.config.system.nixos.tags;
in

{
  ##
  # `map` to make additional SGs easier to add and SG list more readable
  deployment.ec2.securityGroupIds = map (x: resources.ec2SecurityGroups."cluster-${x}-sg".name ) (
    [ "educator-api-private" "witness-public" ]
  );

  networking.firewall.allowedTCPPorts = [
    4010 4011   # Witness ZMQ API
    4030        # Witness HTTP Wallet API
    4040        # Educator HTTP API
  ];

  services.educator_aaa = {
    enable = true;
    port = 4000;
  };

  services.disciplina = let
    config-key = "alpha";

  in rec {
    enable = true;
    type = "educator";


    config."${config-key}" = rec {
      witness = rec {
        appDir = "/var/lib/disciplina-${type}";
        db = {
          path = "${appDir}/witness.db";
          clean = false;
        };
        api.addr = "0.0.0.0:4030";
        keys = {
          type = "basic";
          path = "${appDir}/witness.key";
          genNew = true;
        };
      };

      educator = {
        publishing.period = "30s";
        db.mode = {
          path = "${witness.appDir}/educator.sqlite";
          connNum = 4;
          maxPending = 100;
        };

        keys = {
          path = "${witness.appDir}/educator.key";
          genNew = true;
        };

        api = {
          serverParams.addr = "0.0.0.0:4040";
          botParams = {
            enabled = true;
            operationsDelay = "3s";
            seed = "super secure"; # this is not sensitive data (https://serokell.slack.com/archives/CC92X27D3/p1542652947445200)
          };
          studentAPINoAuth.enabled = false;
          educatorAPINoAuth.enabled = false;
        };
      };
    };

    args = let
      cat = path: ''"$(cat "${path}")"'';
    in {
      inherit config-key;
      bind = address "*";
      peer = map (node: address (if (hasInternalTag node) then node.config.networking.privateIPv4 else node.config.networking.publicIPv4))
        (attrValues (filterAttrs (name2: node: name != name2 && hasWitnessTag node) nodes));
    };
  };

  system.nixos.tags = [ "educator" "witness" ];
}
