n: { lib, name, nodes, pkgs, resources, ... }: with lib;

let
  address = ip: ip + ":4010:4011";
  inherit (nodes.witness-load-balancer.config.networking) publicIPv4;
  isWitness = node: elem "witness" node.config.system.nixos.tags;
  isInternal = n == 0;
in

{
  deployment.ec2.securityGroupIds = map (x: resources.ec2SecurityGroups."cluster-${x}-sg".name ) (
    if isInternal then [ "witness-private" ] else [ "witness-public" ]
  );

  deployment.ec2.elasticIPv4 = lib.mkIf isInternal (lib.mkForce "");

  deployment.keys."witness.yaml".keyFile = ../../keys/staging/witness.yaml;
  deployment.keys."witness-keyfile-pass".keyFile = ../../keys/staging/witness-keyfile-pass;

  networking.firewall.allowedTCPPorts = [ 4040 4041 4030 ];

  services.disciplina-witness = {
    enable = true;

    configFiles = [ (toString pkgs.disciplina-config) "/run/keys/witness.yaml" ];

    args = {
      bind = address publicIPv4;
      bind-internal = address "0.0.0.0";

      config-key = "alpha";

      comm-n = toString (n + 1);

      witness-keyfile = "/var/lib/disciplina-witness/witness.key";
      witness-gen-key = true;
      witness-keyfile-pass = "$(cat /tmp/witness-keyfile-pass)";

      peer = map (node: address node.config.networking.privateIPv4)
        (attrValues (filterAttrs (name2: node: name != name2 && isWitness node) nodes));

      witness-listen = "0.0.0.0:4030";
    };
  };

  system.nixos.tags = [ "witness" ];
}
