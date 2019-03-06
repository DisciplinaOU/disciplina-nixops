n: zone: params@{ lib, name, nodes, pkgs, resources, config, ... }: with lib;

let
  node-type = "witness";
  keys = config.awskeys;
  isInternal = n == 0;
  common = import ./common.nix node-type "" params;
in

{
  ##
  # `map` to make additional SGs easier to add and SG list more readable
  deployment.ec2.securityGroupIds = map (x: resources.ec2SecurityGroups."cluster-${x}-sg".name ) (
    [ "witness-api-private" ] ++
    (if isInternal
      then [ "witness-private" ]
      else [ "witness-public" ])
  );
  deployment.ec2.subnetId = lib.mkForce resources.vpcSubnets."${zone}-subnet";

  networking.firewall.allowedTCPPorts = [
    4010 4011   # Witness ZMQ API
    4030        # Witness HTTP Wallet API
  ];

  services.disciplina = let
    config-key = "alpha";

  in rec {
    enable = true;
    type = node-type;

    config."${config-key}" = {
      inherit (common.zero-pub-fees) core;

      witness = common.default-witness-config // {
        keys.params = {
          paramsType = "committee";
          committee.params = {
            paramsType = "closed";
            participantN = n;
          };
        };
      };
    };

    args = let
      cat = path: ''"$(cat "${path}")"'';
    in {
      inherit config-key;
      comm-sec = cat keys.committee-secret;
    };
  };

  system.nixos.tags = [ "witness" ] ++ (optional isInternal "internal");
}
