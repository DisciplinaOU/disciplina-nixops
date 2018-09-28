# TODO: add AWS ALB to NixOps and use that instead

domain: { config, lib, pkgs, resources, ... }:

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

  boot.kernel.sysctl = {
    "net.core.somaxconn" = 4096;
  };

  networking.firewall.allowedTCPPorts = [ 80 443 ];

  services.nginx = {
    enable = true;

    appendConfig = ''
      worker_processes auto;
    '';

    upstreams.witness = {
      servers = {
        "witness-1:4030" = {};
        "witness-2:4030" = {};
        "witness-3:4030" = {};
        "witness-4:4030" = {};
      };

      extraConfig = ''
        ip_hash;
        keepalive 32;
      '';
    };

    virtualHosts= {
      "${uris.witness}".locations."/".proxyPass = "http://witness";
      "${uris.educator}".locations."/".proxyPass = "http://educator:8090";
      "${uris.faucet}".locations."/".root = pkgs.disciplina-faucet-frontend.override { faucetUrl = "//${uris.faucet}"; };
      "${uris.explorer}".locations."/".root = pkgs.disciplina-explorer-frontend.override { witnessUrl = "//${uris.witness}"; };
    };
  };
}
