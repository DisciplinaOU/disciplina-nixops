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
    [ "educator-api-private" "witness-public" ]
  );

  deployment.ec2.subnetId = lib.mkForce resources.vpcSubnets."${zone}-subnet";

  networking.firewall.allowedTCPPorts = [
    4010 4011   # Witness ZMQ API
    4030        # Witness HTTP Wallet API
    4040        # Educator HTTP API
  ];

  services.postgresql = {
    enable = true;
    package = pkgs.postgresql_9_6;
  };

  services.disciplina = let
    config-key = "alpha";

  in rec {
    enable = true;
    type = node-type;

    config."${config-key}" = rec {
      inherit (common.zero-pub-fees) core;

      witness = common.default-witness-config;
      educator = common.default-educator-config witness false "" false // {
        keys = "${witness.appDir.param.specific.path}/multieducator";
        aaa = {
          serviceUrl = "https://stage-teachmeplease-aaa.stage.tchmpls.com";
          publicKey = "2gSNy2wKSaI4YtGZe_Eaxsdv_BLCfi5kkT9xvxt_O0k";
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

  system.nixos.tags = [ "multi-educator" "witness" ];
}
