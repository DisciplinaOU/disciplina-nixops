{ region ? "eu-west-2" }:

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
