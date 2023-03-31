# TODO: add AWS ALB to NixOps and use that instead

env: domain: zone: params@{ config, lib, name, nodes, pkgs, resources, ... }:

let
  keys = config.awskeys;
  uris = {
    # faucet = "faucet.${domain}";
    # explorer = "explorer.${domain}";
    educator = "educator.${domain}";
    multi-educator = "multi-educator.${domain}";
    # witness = "witness.${domain}";
    validator = "validator.${domain}";
    auth = "auth.${domain}";
  };
  common = import ./common.nix "" "" params;
in
{
  deployment.route53.hostName = lib.mkForce "witness.${domain}";

  deployment.ec2.securityGroupIds = map (x: resources.ec2SecurityGroups."cluster-${x}-sg".name ) (
    [ "http-public" ]
  );

  deployment.ec2.subnetId = lib.mkForce resources.vpcSubnets."${zone}-subnet";
  deployment.ec2.elasticIPv4 = resources.elasticIPs.balancer-eip;

  boot.kernel.sysctl = {
    "net.core.somaxconn" = 4096;
  };

  networking.firewall.allowedTCPPorts = [ 80 443 ];

  services.nginx = {
    enable = true;

    appendConfig = ''
      worker_processes auto;
    '';
    eventsConfig = ''
      worker_connections 16384;
    '';
    commonHttpConfig = ''
      access_log syslog:server=unix:/dev/log,tag=nginx,severity=info combined;
    '';

    upstreams.educator = {
      servers."educator:4040" = {};
      extraConfig = "keepalive 32;";
    };

    upstreams.multi-educator = {
      servers."multi-educator:4040" = {};
      extraConfig = "keepalive 32;";
    };

    upstreams.auth = {
      servers."localhost:8000" = {};
      extraConfig = "keepalive 32;";
    };

    virtualHosts= {
      "${uris.educator}".locations."/".proxyPass = "http://educator";
      "${uris.multi-educator}".locations = {
        "/api".proxyPass = "http://multi-educator";
        "/" = {
          root = pkgs.disciplina-educator-spa.override {
            aaaUrl = "//${uris.auth}";
            educatorUrl = "//${uris.multi-educator}";
          };
          tryFiles = "$uri /index.html";
        };
      };

      "${uris.auth}".locations."/".proxyPass = "http://auth";

      "${uris.validator}" = {
        locations = {
	  "/api".proxyPass = "http://multi-educator";
          "/".root = pkgs.disciplina-validatorcv.override { witnessUrl = "//${uris.multi-educator}"; };
        };
        default = true;
      };
    };
  };

  services.postgresql = {
    enable = true;
    package = pkgs.postgresql;
  };

  systemd.services.metamask-auth = {
    description = "Hello world application";

    after = [ "network.target" "postgresql.service" ];
    wantedBy = [ "multi-user.target" ];

    # We're going to run it on port 8000 in production
    environment = {
      PORT = "8000";
      PSQL_CONN_STRING = "postgresql://disciplina@/disciplina?host=/tmp";
      AUTH_SECRET_PATH = ../../secret.pem;   # SHOULD BE PUT MANUALLY ON DEPLOYER BEFORE DEPLOYMENT
    };
    serviceConfig = {
      ExecStartPre = common.postgres-pre-start;
      ExecStart = "${pkgs.nodejs-16_x}/bin/node ${pkgs.metamask-auth-service}";
      # For security reasons we'll run this process as a special 'nodejs' user
      User = "disciplina";
      Restart = "always";
    };
  };

  users.extraUsers = {
    disciplina = {
      extraGroups = [ "keys" ];
      isSystemUser = true;
    };
  };
}
