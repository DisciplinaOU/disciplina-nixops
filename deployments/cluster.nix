{ region ? "eu-west-1", zone ? "serokell.review" }:

{
  network.description = "Disciplina cluster";

  defaults = { resources, ... }: {
    deployment.targetEnv = "ec2";

    deployment.ec2 = {
      inherit region;
      instanceType = "t2.medium";
      keyPair = resources.ec2KeyPairs.cluster-key;
      securityGroups = [ resources.ec2SecurityGroups.cluster-ssh.name ];
    };

    imports = [ ../modules ];

    nixpkgs.overlays = [(final: previous: {
      # TODO: <disciplina>
      inherit (import ../../disciplina/release.nix)
        disciplina-config
        disciplina-static;
    })];

    services.nginx = {
      recommendedOptimisation = true;
      recommendedProxySettings = true;
      recommendedTlsSettings = true;
    };

    services.sshguard.enable = true;
  };

  witness-1 = import ./cluster/witness.nix 1;
  witness-2 = import ./cluster/witness.nix 2;
  witness-3 = import ./cluster/witness.nix 3;
  witness-4 = import ./cluster/witness.nix 4;

  witness-load-balancer = import ./cluster/witness-load-balancer.nix zone;

  resources.ec2KeyPairs.cluster-key = { inherit region; };

  resources.ec2SecurityGroups.cluster-ssh = {
    inherit region;
    rules = [{
      fromPort = 22;
      toPort = 22;
      sourceIp = "0.0.0.0/0";
    }];
  };
}
