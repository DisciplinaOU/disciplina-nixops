{ region ? "eu-west-2"
, env ? builtins.getEnv "NIX_ENV"
, pkgs ? import ../pkgs.nix }:

{
  network.description = "Disciplina - shared infra";
  require = [ ./shared-resources.nix ];

  disciplina-deployer = { config, lib, pkgs, resources, ... }: {
    deployment.targetEnv = "ec2";

    deployment.ec2 = {
      inherit region;
      keyPair = resources.ec2KeyPairs.deployer-keypair;

      ebsInitialRootDiskSize = 256;
      instanceType = "t2.xlarge";
      instanceProfile = "ReadDisciplinaSecrets";
      securityGroupIds = with resources.ec2SecurityGroups;
        [ ssh-public-sg.name ];
    };

    deployment.keys = {
      buildkite-token.keyFile = ../keys/production/buildkite-token;

      # Continuous delivery secrets
      # "aws-credentials".keyFile = ../keys/staging/aws-credentials;
      # "faucet-key.json".keyFile = ../keys/staging/faucet-key.json;
      # "witness.yaml".keyFile = ../keys/staging/witness.yaml;
    };

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

    nixpkgs.overlays = [ (import ../pkgs) ];

    services.buildkite-agent = {
      #enable = true;

      runtimePackages = with pkgs; [ bash gnutar nix-with-cachix ];

      tags.hostname = config.networking.hostName;
      tags.system = pkgs.system;

      # tokenPath = "${config.awsKeys.buildkite-token.path}";
    };

    # awsKeys.buildkite-token = {
    #   services = [ "buildkite-agent" ];
    #   secretId = "${env}/disciplina/deployment";
    # };
  };

}
