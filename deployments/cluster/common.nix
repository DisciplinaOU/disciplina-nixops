type: domain: { lib, name, nodes, pkgs, ... }: with lib;

let
  address = ip: ip + ":4010:4011";
  hasWitnessTag = node: elem "witness" node.config.system.nixos.tags;
in
{
  zero-pub-fees.core.fee.publication = {
    type = "linear";
    coeffs = {
      minimal = 0;
      multiplier = 0;
    };
  };

  default-witness-config = rec {
    appDir.param = {
      paramType = "specific";
      specific.path = "/var/lib/disciplina-${type}";
    };
    db = {
      path = "${appDir.param.specific.path}/witness.db";
      clean = true;
    };
    api.maybe = {
      maybeType = "just";
      just.addr = "0.0.0.0:4030";
    };
    network = {
      peers = map (node: address node.config.networking.privateIPv4)
        (attrValues (filterAttrs (name2: node: name != name2 && hasWitnessTag node) nodes));
      ourAddress = address "*";
    };
    keys.params = {
      paramsType = "basic";
      basic = {
        path = "${appDir.param.specific.path}/witness.key";
        genNew = true;
      };
    };
  };

  default-educator-config = witness: bot-enabled: student-api-noauth: educator-api-noauth: {
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
        paramsType = if bot-enabled then "enabled" else "disabled";
        enabled = if bot-enabled then {
          operationsDelay = "3s";
          seed = "super secure"; # this is not sensitive data (https://serokell.slack.com/archives/CC92X27D3/p1542652947445200)
        } else {};
      };
      studentAPINoAuth = if student-api-noauth != "" then {
        enabled = true;
        data = student-api-noauth;
      } else {
        enabled = false;
      };
      educatorAPINoAuth = if educator-api-noauth then {
        enabled = true;
        data = [];
      } else {
        enabled = false;
      };
    };

    certificates = {
      latex = "${pkgs.pdf-generator-xelatex}/bin/xelatex";
      # TODO: this path with all those versions should be de-hardcoded somehow
      resources = "${pkgs.disciplina-data}/share/ghc-8.2.2/x86_64-linux-ghc-8.2.2/disciplina-pdfs-0.1.0.0/template";
      downloadBaseUrl = "https://${type}.${domain}/api/certificates/v1/cert";
      issuer = {
        name = "Disciplina Educator Bot";
        website = "http://disciplina.io";
      };
    };
  };

  postgres-pre-start = let
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
}
