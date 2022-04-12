domain: zone:
params@{ lib, name, nodes, pkgs, resources, ... }:

with lib;
let
  node-type = "multi-educator";
  common = import ./common.nix node-type domain params;
in

{
  # Fix the redefinition of `educator` subdomain
  deployment.route53.hostName = lib.mkForce "${name}-inner.${domain}";

  ##
  # `map` to make additional SGs easier to add and SG list more readable
  deployment.ec2.securityGroupIds = map (x: resources.ec2SecurityGroups."cluster-${x}-sg".name ) (
    [ "educator-api-private" ]
  );

  deployment.ec2.subnetId = lib.mkForce resources.vpcSubnets."${zone}-subnet";

  networking.firewall.allowedTCPPorts = [
    # 4010 4011   # Witness ZMQ API
    # 4030        # Witness HTTP Wallet API
    4040        # Educator HTTP API
  ];

  services.postgresql = {
    enable = true;
    package = pkgs.postgresql;
  };

  services.disciplina = let
    config-key = "new-web3";
    witness = common.default-witness-config;

  in rec {
    enable = true;
    type = node-type;

    config."${config-key}" = {
      educator = common.default-educator-config witness false "" false // {
        keys = "${witness.appDir.param.specific.path}/multieducator";
        aaa = {
          serviceUrl = "https://auth.${domain}";
          publicKey = "fAc_hcle5psCxGio6cBjs2BRekX29iwg2JdA97JH-HM";
        };
      };
    };

    args = {
      inherit config-key;
    };

    requires = [ "postgresql.service" ];
    serviceConfig = {
      ExecStartPre = common.postgres-pre-start;
    };
  };

  system.nixos.tags = [ "multi-educator" ];
}
