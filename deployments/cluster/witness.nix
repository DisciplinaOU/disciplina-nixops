n: { lib, name, nodes, pkgs, ... }: with lib;

let
  address = ip: ip + ":4010:4011";
  inherit (nodes.witness-load-balancer.config.networking) publicIPv4;
  isWitness = node: elem "witness" node.config.system.nixos.tags;
in

{
  services.disciplina-witness = {
    enable = true;

    args = {
      bind = address publicIPv4;
      bind-internal = address "0.0.0.0";

      config = pkgs.disciplina-config;
      config-key = "alpha";

      comm-n = n;
      comm-sec = "dscp-alpha-00000000"; # TODO: read from file

      peer = map (node: address node.config.networking.privateIPv4)
        (attrValues (filterAttrs (name2: node: name != name2 && isWitness node) nodes));

      witness-listen = "0.0.0.0:4030";
    };
  };

  system.nixos.tags = [ "witness" ];
}
