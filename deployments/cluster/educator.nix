domain: zone: student-api-noauth: educator-api-noauth:
params@{ lib, name, nodes, pkgs, resources, ... }:

with lib;
let
  node-type = "educator";
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

  in {
    enable = true;
    type = node-type;

    config."${config-key}" = rec {
      educator = common.default-educator-config witness
        true student-api-noauth educator-api-noauth;
    };

    args = {
      inherit config-key;
    };

    requires = [ "postgresql.service" ];
    serviceConfig = {
      ExecStartPre = common.postgres-pre-start;
    };
  };

  system.nixos.tags = [ "educator" "witness" ];
}
