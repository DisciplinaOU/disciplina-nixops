{ region ? "eu-west-2"
, env ? builtins.getEnv "DISCIPLINA_ENV"
, pkgs ? import ../pkgs.nix
, ...}:

{
  network.description = "Disciplina - shared infra";
  require = [ ./shared-resources.nix ];

  disciplina-deployer = { config, lib, pkgs, resources, ... }: {
    deployment.targetEnv = "ec2";

    deployment.ec2 = with resources; {
      inherit region;
      keyPair = ec2KeyPairs.deployer-keypair;

      ebsInitialRootDiskSize = 256;
      instanceType = "t2.xlarge";
      instanceProfile = "ReadDisciplinaSecrets";
      associatePublicIpAddress = true;
      subnetId = vpcSubnets.deployer-subnet;
      securityGroupIds = with ec2SecurityGroups;
        [ ssh-public-sg.name ];
    };

    deployment.keys = {
      buildkite-token.keyFile = ../keys/production/buildkite-token;

      # Continuous delivery secrets
      # "aws-credentials".keyFile = ../keys/staging/aws-credentials;
      # "faucet-key.json".keyFile = ../keys/staging/faucet-key.json;
      # "witness.yaml".keyFile = ../keys/staging/witness.yaml;
    };

    # networking.hostName = "disciplina-deployer";
    documentation.enable = false;

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

    #services.buildkite-agent = {
    #  #enable = true;

    #  runtimePackages = with pkgs; [ bash gnutar nix-with-cachix ];

    #  tags.hostname = config.networking.hostName;
    #  tags.system = pkgs.system;

    #  # tokenPath = "${config.awsKeys.buildkite-token.path}";
    #};

    # awsKeys.buildkite-token = {
    #   services = [ "buildkite-agent" ];
    #   secretId = "${env}/disciplina/deployment";
    # };

    users.extraGroups.nixops = {};
    users.users.nixops = {
      isSystemUser = true;
      group = "nixops";
      # keys: read nixops ephemeral keys
      # users: read nix files from user homes
      extraGroups = [ "keys" "users" ];
      home = "/var/lib/nixops";
      createHome = true;
    };

    security.sudo = {
      extraRules = [
        {
          ##
          # Allow members of the `wheel` group, as well as user `buildkite-agent`
          # to execute `nixops deploy` as the `nixops` user.
          commands = [
            { command = "${pkgs.nixops-git}/bin/nixops deploy *";
            options = [ "SETENV" "NOPASSWD" ]; }
            { command = "${pkgs.nixops-git}/bin/nixops info";
            options = [ "SETENV" "NOPASSWD" ]; }
            { command = "${pkgs.nixops-git}/bin/nixops list";
            options = [ "SETENV" "NOPASSWD" ]; }
            { command = "${pkgs.nixops-git}/bin/nixops check";
            options = [ "SETENV" "NOPASSWD" ]; }
          ];
          groups = [ "wheel" "nixops" ];
          # users = [ "buildkite-agent" ];
          runAs = "nixops";
        }
      ];
      extraConfig = ''
        Defaults env_keep+=NIX_PATH
      '';
    };
  };

}
