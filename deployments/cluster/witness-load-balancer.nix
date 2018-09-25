# TODO: add AWS ALB to NixOps and use that instead

zone: { deployment, pkgs, ... }:

{
  deployment.route53.hostName = "witness.${zone}";

  services.nginx = {
    enable = true;

    boot.kernel.sysctl = {
      "net.core.somaxconn" = 4096;
    };

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

    virtualHosts."${deployment.route53.hostName}" = {
      enableACME = true;

      # TODO:
      # locations."/explore".root = pkgs.disciplina-explorer-frontend;
      locations."/".proxyPass = "http://witness";
    };
  };
}