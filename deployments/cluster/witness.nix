n: zone: { lib, name, nodes, pkgs, resources, config, ... }: with lib;

let
  keys = config.dscp.keys;
  address = ip: ip + ":4010:4011";
  hasWitnessTag = node: elem "witness" node.config.system.nixos.tags;
  isInternal = n == 0;
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
    type = "witness";

    config."${config-key}".witness = rec {
      appDir = "/var/lib/disciplina-${type}";
        db = {
          path = "${appDir}/witness.db";
          clean = false;
        };
      api.addr = "0.0.0.0:4030";
    };

    args = let
      cat = path: ''"$(cat "${path}")"'';
    in {
      inherit config-key;
      bind = address "*";
      comm-n = toString n;
      comm-sec = cat keys.committee-secret;
      peer = map (node: address node.config.networking.privateIPv4)
        (attrValues (filterAttrs (name2: node: name != name2 && hasWitnessTag node) nodes));
    };
  };

  system.nixos.tags = [ "witness" ] ++ (optional isInternal "internal");
}
