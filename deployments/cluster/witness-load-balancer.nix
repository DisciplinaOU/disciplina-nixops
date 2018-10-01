# TODO: add AWS ALB to NixOps and use that instead

env: domain: { config, lib, pkgs, resources, ... }:

let
  uris = {
    faucet = "faucet.${domain}";
    explorer = "explorer.${domain}";
    educator = "educator.${domain}";
    witness = "witness.${domain}";
  };

in
{
  deployment.route53.hostName = lib.mkForce "witness.${domain}";

  deployment.ec2.securityGroupIds = map (x: resources.ec2SecurityGroups."cluster-${x}-sg".name ) (
    [ "http-public" ]
  );

  deployment.keys."faucet-key.json".keyFile = ../../keys + "/${env}/faucet-key.json";

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
      "${uris.explorer}".locations."/".root = pkgs.disciplina-explorer-frontend.override { witnessUrl = "//${uris.witness}"; };

      "${uris.faucet}" = {
        locations = {
          "= /api/faucet/v1/".index = "index.html";
          "/api".proxyPass = "http://faucet";
          "/".root = pkgs.disciplina-faucet-frontend.override { faucetUrl = "//${uris.faucet}"; };
        };
      };
    };
  };

  services.disciplina = {
    enable = true;
    type = "faucet";
    keyFiles = [ "faucet-key.json" ];
    args = {
      config = toString pkgs.disciplina-config;
      config-key = "alpha";

      faucet-keyfile = "/tmp/faucet-key.json";

      faucet-listen = "127.0.0.1:4014";
      translated-amount = "20";
      witness-backend = "http://witness1:4030";
    };
  };
}
