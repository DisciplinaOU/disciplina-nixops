# TODO: add AWS ALB to NixOps and use that instead

env: domain: { config, lib, pkgs, resources, ... }:

let
  keys = config.dscp.keys;
  uris = {
    faucet = "faucet.${domain}";
    explorer = "explorer.${domain}";
    educator = "educator.${domain}";
    witness = "witness.${domain}";
    validator = "validator.${domain}";
  };
in
{
  deployment.route53.hostName = lib.mkForce "witness.${domain}";

  deployment.ec2.securityGroupIds = map (x: resources.ec2SecurityGroups."cluster-${x}-sg".name ) (
    [ "http-public" ]
  );

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

    upstreams.faucet = {
      servers."127.0.0.1:4014" = {};
      extraConfig = "keepalive 32;";
    };

    virtualHosts= {
      "${uris.witness}".locations."/".proxyPass = "http://witness";
      "${uris.educator}".locations."/".proxyPass = "http://educator";
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

  in rec {
    enable = true;
    type = "faucet";

    config."${config-key}".faucet = {
      appDir = "/var/lib/disciplina-${type}";
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