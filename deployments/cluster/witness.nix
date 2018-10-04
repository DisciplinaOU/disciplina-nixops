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
      (if isInternal then [ "witness-private" ] else [ "witness-public" ])
  );

  ## We do not allocate an elastic IP for the internal witness node, so don't try to associate it
  deployment.ec2.elasticIPv4 = lib.mkIf (n == 0) (lib.mkForce "");

  networking.firewall.allowedTCPPorts = [
    4040 4041   # Witness ZMQ API
    4030        # Witness HTTP Wallet API
  ];

  services.disciplina = {
    enable = true;
    type = "witness";

    args = let
      cat = path: ''"$(cat "${path}")"'';
      stateDir = "/var/lib/disciplina-witness";

      publicIP = ''"$(curl "http://169.254.169.254/latest/meta-data/public-ipv4")"'';
      privateIP = ''"$(curl "http://169.254.169.254/latest/meta-data/local-ipv4")"'';
    in {
      bind = address (if isInternal then privateIP else publicIP);
      bind-internal = address privateIP;

      db-path = "${stateDir}/witness.db";

      config-key = "alpha";

      comm-n = toString n;
      comm-sec = cat keys.committee-secret;

      config = toString pkgs.disciplina-config;

      peer = map (node: address (if (hasInternalTag node) then node.config.networking.privateIPv4 else node.config.networking.publicIPv4))
        (attrValues (filterAttrs (name2: node: name != name2 && hasWitnessTag node) nodes));

      witness-listen = "0.0.0.0:4030";
    };
  };

  system.nixos.tags = [ "witness" ] ++ (optional isInternal "internal");
}
