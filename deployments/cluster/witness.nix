env: n: { lib, name, nodes, pkgs, resources, config, ... }: with lib;

let
  keys = config.dscp.keys;
  address = ip: ip + ":4010:4011";
  hasWitnessTag = node: elem "witness" node.config.system.nixos.tags;
  hasInternalTag = node: elem "internal" node.config.system.nixos.tags;
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

  ## We do not allocate an elastic IP for the internal witness node, so don't try to associate it
  deployment.ec2.elasticIPv4 = lib.mkIf (n == 0) (lib.mkForce "");

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
      appDir.param = {
        paramType = "specific";
        specific.path = "/var/lib/disciplina-${type}";
      };
      db = {
        path = "${appDir}/witness.db";
        clean = false;
      };
      api.maybe = {
        maybeType = "just";
        just.addr = "0.0.0.0:4030";
      };
    };

    args = let
      cat = path: ''"$(cat "${path}")"'';
    in {
      inherit config-key;
      bind = address "*";
      comm-n = toString n;
      comm-sec = cat keys.committee-secret;
      peer = map (node: address (if (hasInternalTag node) then node.config.networking.privateIPv4 else node.config.networking.publicIPv4))
        (attrValues (filterAttrs (name2: node: name != name2 && hasWitnessTag node) nodes));
    };
  };

  system.nixos.tags = [ "witness" ] ++ (optional isInternal "internal");
}
