{ region ? "eu-central-1"
, env ? builtins.getEnv "DISCIPLINA_ENV"
, pkgs ? import ../pkgs.nix
, ...}:

let
  inherit (pkgs) lib;
  wheel = [ "chris" "kirelagin" "lars" "yorick" ];
  expandUser = _name: keys: {
    extraGroups = (lib.optional (builtins.elem _name wheel) "wheel") ++ [ "systemd-journal" ];
    isNormalUser = true;
    openssh.authorizedKeys.keys = keys;
  };

  getNixopsSecurityCredentials = "${pkgs.curl}/bin/curl --silent --show-error \"http://169.254.169.254/latest/meta-data/iam/security-credentials/serokell-nixops\"";

  nixopsWrapper = pkgs.writeShellScriptBin "nixops" ''
    [ "$(whoami)" = "nixops" ] || ( echo Please run with sudo -u nixops; exit 1 )

    # Download AWS credentials using the serokell-nixops instance profile and
    # forward them to nixops
    key_json="$(sudo ${getNixopsSecurityCredentials})"

    cat > "/var/lib/nixops/.ec2-keys" <<EOF
    aws_access_key_id=$(echo "$key_json" | ${pkgs.jq}/bin/jq -r .AccessKeyId)
    aws_secret_access_key=$(echo "$key_json" | ${pkgs.jq}/bin/jq -r .SecretAccessKey)
    EOF

    ${pkgs.nixops}/bin/nixops "$@"
    rv=$?

    cd /var/lib/nixops/.nixops
    [ -e .git ] || git init -q
    git add .
    git commit -qm "nixops $*"
    exit $rv
  '';

in {
  network.description = "Disciplina - shared infra";
  require = [ ./shared-resources.nix ];

  disciplina-deployer = { config, resources, ... }: {
    deployment.targetEnv = "ec2";

    deployment.ec2 = with resources; {
      inherit region;
      keyPair = ec2KeyPairs.deployer-keypair;

      ebsInitialRootDiskSize = 256;
      instanceType = "t2.xlarge";
      instanceProfile = "serokell-nixops";
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

    environment.systemPackages = [ nixopsWrapper ];

    nix = {
      binaryCaches = [
        "https://cache.nixos.org"
        "https://disciplina.cachix.org"
      ];

      binaryCachePublicKeys = [
        "disciplina.cachix.org-1:zDeIFV5cu22v04EUuRITz/rYxpBCGKY82x0mIyEYjxE="
      ];
    };

    nixpkgs.pkgs = pkgs;

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
    users.mutableUsers = false;
    users.users = {
      nixops = {
        isSystemUser = true;
        group = "nixops";
        # keys: read nixops ephemeral keys
        # users: read nix files from user homes
        extraGroups = [ "keys" "users" ];
        home = "/var/lib/nixops";
        createHome = true;
      };
    } // lib.mapAttrs expandUser (import ./ssh-keys.nix);

    security.sudo = {
      extraRules = [
        {
          ##
          # Allow members of the `wheel` group, as well as user `buildkite-agent`
          # to execute `nixops deploy` as the `nixops` user.
          commands = [
            { command = "${nixopsWrapper}/bin/nixops deploy *";
            options = [ "SETENV" "NOPASSWD" ]; }
            { command = "${nixopsWrapper}/bin/nixops info";
            options = [ "SETENV" "NOPASSWD" ]; }
            { command = "${nixopsWrapper}/bin/nixops list";
            options = [ "SETENV" "NOPASSWD" ]; }
            { command = "${nixopsWrapper}/bin/nixops check";
            options = [ "SETENV" "NOPASSWD" ]; }
          ];
          groups = [ "wheel" "nixops" ];
          # users = [ "buildkite-agent" ];
          runAs = "nixops";
        }
        {
          commands = [
            { command = getNixopsSecurityCredentials;
              options = [ "NOSETENV" "NOPASSWD" ]; }
          ];
          runAs = "root";
          users = [ "nixops" ];
        }
      ];
      extraConfig = ''
        Defaults env_keep+=NIX_PATH
      '';

      wheelNeedsPassword = false;
    };
  };

}
