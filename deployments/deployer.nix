{ region ? "eu-west-1" }:

{
  network.description = "Disciplina cluster deployer";

  deployer-instance = { config, lib, pkgs, resources, ... }: {
    deployment.targetEnv = "ec2";

    deployment.ec2 = {
      inherit region;

      ebsInitialRootDiskSize = 256;
      instanceType = "t2.xlarge";
      keyPair = resources.ec2KeyPairs.deployer-key;
      securityGroups = [ resources.ec2SecurityGroups.deployer-ssh ];
    };

    deployment.keys.buildkite-token.keyFile = ../keys/buildkite-token;

    networking.hostName = "disciplina-deployer";

    nix = {
      binaryCaches = [
        "https://cache.nixos.org"
        "https://disciplina.cachix.org"
      ];

      binaryCachePublicKeys = [
        "disciplina.cachix.org-1:zDeIFV5cu22v04EUuRITz/rYxpBCGKY82x0mIyEYjxE="
      ];
    };

    services.buildkite-agent = {
      enable = true;
      package = pkgs.buildkite-agent3;
      runtimePackages = with pkgs; [ bash gnutar nix ];
      tokenPath = "/run/keys/buildkite-token";
      # populate os (linux, darwin, windows), hostname, machine-id (/etc/machine-id)
      extraConfig = "tags-from-host=true";
    };
  };

  resources.ec2KeyPairs.deployer-key = { inherit region; };

  resources.ec2SecurityGroups.deployer-ssh = {
    inherit region;
    rules = [{
      fromPort = 22;
      toPort = 22;
      sourceIp = "0.0.0.0/0";
    }];
  };
}
