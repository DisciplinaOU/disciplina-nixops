env: n: { lib, name, nodes, pkgs, resources, ... }: with lib;

let
  keys = config.dscp.keys;
  address = ip: ip + ":4010:4011";
  hasWitnessTag = node: elem "witness" node.config.system.nixos.tags;
  hasInternalTag = node: elem "internal" node.config.system.nixos.tags;
in

{
  ##
  # `map` to make additional SGs easier to add and SG list more readable
  deployment.ec2.securityGroupIds = map (x: resources.ec2SecurityGroups."cluster-${x}-sg".name ) (
    [ "educator-api-private" "witness-api-private" ]
  );

  networking.firewall.allowedTCPPorts = [
    4040 4041   # Witness ZMQ API
    4030        # Witness HTTP Wallet API
    4040        # Educator HTTP API
  ];

  services.disciplina = rec {
    enable = true;
    type = "educator";

    args = let
      cat = path: ''"$(cat "${path}")"'';
      stateDir = "/var/lib/disciplina-${type}";

      publicIP = "$(curl http://169.254.169.254/latest/meta-data/public-ipv4 2>/dev/null)";
      privateIP = "$(curl http://169.254.169.254/latest/meta-data/local-ipv4 2>/dev/null)";
    in {
      bind = address publicIP;
      bind-internal = address privateIP;

      config-key = "alpha";

      config = toString pkgs.disciplina-config;

      peer = map (node: address (if (hasInternalTag node) then node.config.networking.privateIPv4 else node.config.networking.publicIPv4))
        (attrValues (filterAttrs (name2: node: name != name2 && hasWitnessTag node) nodes));

      witness-listen = "0.0.0.0:4030";
      educator-listen = "0.0.0.0:4040";

      sql-path = "${stateDir}/educator.db";
      educator-bot = true;
      educator-bot-delay = "3s";

      educator-keyfile = "${stateDir}/educator.key";
      educator-gen-key = true;
    };
  };

  system.nixos.tags = [ "educator" "witness" ];
}
