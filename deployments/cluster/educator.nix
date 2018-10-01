env: n: { lib, name, nodes, pkgs, resources, ... }: with lib;

let
  address = ip: ip + ":4010:4011";
  inherit (nodes.witness-load-balancer.config.networking) publicIPv4;
  isWitness = node: elem "witness" node.config.system.nixos.tags;
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

  ##
  # For each secret data point:
  # * Add its file to deployment.keys
  # * Add its name to services.disciplina-witness.keyFiles
  # * Wrap its value in `services.disciplina-witness.args` with `cat`
  deployment.keys = {
    "witness-comm-sec".keyFile = ../../keys + "/${env}/witness/comm-sec";
  };

  services.disciplina = rec {
    enable = true;
    type = "educator";

    ##
    # These are copied to /tmp/${name}
    # For use with `cat` helper function to wrap secrets
    # Also adds dependency on nixops keyfile services
    keyFiles = [
      "witness-comm-sec"
    ];

    args = let
      cat = name: ''"$(cat "/tmp/${name}" 2>/dev/null)"'';
      stateDir = "/var/lib/disciplina-${type}";
    in {
      ##
      # --educator-keyfile $tmp_files/educator.key
      # --educator-gen-key
      # --sql-path $tmp_files/educator.db
      # --educator-listen 127.0.0.1:8090
      # --educator-bot
      # --educator-bot-delay 3s

      bind = address publicIPv4;
      bind-internal = address "0.0.0.0";

      config-key = "alpha";

      comm-n = toString n;
      comm-sec = cat "witness-comm-sec";

      config = toString pkgs.disciplina-config;

      peer = map (node: address node.config.networking.privateIPv4)
        (attrValues (filterAttrs (name2: node: name != name2 && isWitness node) nodes));

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
