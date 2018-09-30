n: { lib, name, nodes, pkgs, resources, ... }: with lib;

let
  address = ip: ip + ":4010:4011";
  inherit (nodes.witness-load-balancer.config.networking) publicIPv4;
  isWitness = node: elem "witness" node.config.system.nixos.tags;
  isInternal = n == 0;
in

{
  ##
  # `map` to make additional SGs easier to add and SG list more readable
  deployment.ec2.securityGroupIds = map (x: resources.ec2SecurityGroups."cluster-${x}-sg".name ) (
    [ "witness-api-private" ] ++
      (if isInternal then [ "witness-private" ] else [ "witness-public" ])
  );

  ## We do not allocate an elastic IP for the internal witness node, so don't try to associate it
  deployment.ec2.elasticIPv4 = lib.mkIf isInternal (lib.mkForce "");

  ##
  # For each secret data point:
  # * Add its file to deployment.keys
  # * Add its name to services.disciplina-witness.keyFiles
  # * Wrap its value in `services.disciplina-witness.args` with `cat`
  deployment.keys = {
    "witness-comm-sec".keyFile = ../../keys/staging/witness/comm-sec;
  };

  networking.firewall.allowedTCPPorts = [
    4040 4041   # Witness ZMQ API
    4030        # Witness HTTP Wallet API
  ];

  services.disciplina = {
    enable = true;
    type = "witness";

    ##
    # These are copied to /tmp/${name}
    # For use with `cat` helper function to wrap secrets
    # Also adds dependency on nixops keyfile services
    keyFiles = [
      "witness-comm-sec"
    ];

    args = let
      cat = name: ''"$(cat "/tmp/${name}" 2>/dev/null)"'';
      stateDir = "/var/lib/disciplina-witness";
    in {
      bind = address publicIPv4;
      bind-internal = address "0.0.0.0";

      db-path = "${stateDir}/witness.db";

      config-key = "alpha";

      comm-n = toString n;
      comm-sec = cat "witness-comm-sec";

      config = toString pkgs.disciplina-config;

      peer = map (node: address node.config.networking.privateIPv4)
        (attrValues (filterAttrs (name2: node: name != name2 && isWitness node) nodes));

      witness-listen = "0.0.0.0:4030";
    };
  };

  system.nixos.tags = [ "witness" ];
}
