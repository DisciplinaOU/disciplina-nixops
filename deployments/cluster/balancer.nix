# TODO: add AWS ALB to NixOps and use that instead

env: domain: zone: { config, lib, pkgs, resources, ... }:

let
  keys = config.awskeys;
  uris = {
    faucet = "faucet.${domain}";
    explorer = "explorer.${domain}";
    educator = "educator.${domain}";
    multi-educator = "multi-educator.${domain}";
    witness = "witness.${domain}";
    validator = "validator.${domain}";
  };
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

    upstreams.witness = {
      servers = {
        "witness1:4030" = {};
        "witness2:4030" = {};
        "witness3:4030" = {};
      };

      extraConfig = ''
        ip_hash;
        keepalive 32;
      '';
    };

    upstreams.educator = {
      servers."educator:4040" = {};
      extraConfig = "keepalive 32;";
    };

    upstreams.multi-educator = {
      servers."multi-educator:4040" = {};
      extraConfig = "keepalive 32;";
    };

    upstreams.faucet = {
      servers."127.0.0.1:4014" = {};
      extraConfig = "keepalive 32;";
    };

    virtualHosts= {
      "${uris.witness}".locations."/".proxyPass = "http://witness";
      "${uris.educator}".locations."/".proxyPass = "http://educator";
      "${uris.multi-educator}".locations."/".proxyPass = "http://multi-educator";
      "${uris.explorer}".locations = {
        "/api".proxyPass = "http://witness";
        "/".root = pkgs.disciplina-explorer-frontend.override { witnessUrl = "//${uris.witness}"; };
      };

      "${uris.faucet}".locations = {
        "= /api/faucet/v1/".index = "index.html";
        "/api".proxyPass = "http://faucet";
        "/".root = pkgs.disciplina-faucet-frontend.override { faucetUrl = "//${uris.faucet}"; };
      };

      "${uris.validator}".locations = {
        "/".root = pkgs.disciplina-validatorcv.override { witnessUrl = "//${uris.witness}"; };
      };
    };
  };

  services.disciplina = let
    config-key = "alpha";
    getSecret = k: ''"$(aws secretsmanager get-secret-value --secret-id ${env}/disciplina/cluster | jq -r .SecretString)"'';

  in rec {
    enable = true;
    type = "faucet";

    config."${config-key}".faucet = {
      appDir.param = {
        paramType = "specific";
        specific.path = "/var/lib/disciplina-${type}";
      };
      api.addr = "127.0.0.1:4014";
      witnessBackend = "http://witness1:4030";
      transferredAmount = 20;
      keys = {
        path = toString keys.faucet-key;
        genNew = false;
      };
    };

    args = {
      inherit config-key;
    };
  };
}
