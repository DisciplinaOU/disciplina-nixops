# TODO: add AWS ALB to NixOps and use that instead

env: domain: zone: { config, lib, pkgs, resources, ... }:

let
  keys = config.awskeys;
  uris = {
    # faucet = "faucet.${domain}";
    # explorer = "explorer.${domain}";
    educator = "educator.${domain}";
    multi-educator = "multi-educator.${domain}";
    # witness = "witness.${domain}";
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

    upstreams.educator = {
      servers."educator:4040" = {};
      extraConfig = "keepalive 32;";
    };

    upstreams.multi-educator = {
      servers."multi-educator:4040" = {};
      extraConfig = "keepalive 32;";
    };

    virtualHosts= {
      "${uris.educator}".locations."/".proxyPass = "http://educator";
      "${uris.multi-educator}".locations = {
        "/api".proxyPass = "http://multi-educator";
        "/" = {
          root = pkgs.disciplina-educator-spa.override {
            aaaUrl = "https://stage-teachmeplease-aaa.stage.tchmpls.com";
            educatorUrl = "//${uris.multi-educator}";
          };
          tryFiles = "$uri /index.html";
        };
      };

      "${uris.validator}".locations = {
        "/".root = pkgs.disciplina-validatorcv.override { witnessUrl = "//${uris.multi-educator}"; };
      };
    };
  };
}
