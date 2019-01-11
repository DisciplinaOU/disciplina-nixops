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

  getNixopsSecurityCredentials = pkgs.writeScript "getNixopsSecurityCredentials" ''
    #!${pkgs.bash}/bin/bash
    ${pkgs.curl}/bin/curl --silent --show-error \
      http://169.254.169.254/latest/meta-data/iam/security-credentials/serokell-nixops
  '';
  getBuildkiteSecrets = pkgs.writeScript "getBuildkiteSecrets" ''
    #!${pkgs.bash}/bin/bash
    "${pkgs.awscli}/bin/aws secretsmanager get-secret-value --secret-id production/disciplina/buildkite --region eu-central-1 \
    | ${pkgs.jq}/bin/jq -r .SecretString
  '';
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
    [ -e .git ] || ${pkgs.git}/bin/git init -q
    ${pkgs.git}/bin/git add .
    ${pkgs.git}/bin/git diff-index --quiet HEAD || \
      ${pkgs.git}/bin/git -c user.name=nixops -c user.email= commit -qm "nixops $*"
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

    # limit access to amazon roles and keys to root
    networking.firewall.extraCommands = ''
      iptables -A OUTPUT -m owner -p tcp -d 169.254.169.254 ! --uid-owner root -j nixos-fw-log-refuse
    '';
    networking.firewall.extraStopCommands = ''
      iptables -D OUTPUT -m owner -p tcp -d 169.254.169.254 ! --uid-owner root -j nixos-fw-log-refuse || true
    '';

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

    services.buildkite-agent = {
      #enable = true;

      runtimePackages = with pkgs; [ bash gnutar nix-with-cachix ];

      tags.hostname = config.networking.hostName;
      tags.system = pkgs.system;

      # tokenPath is cat'd into the buildkite config file, as root
      # https://github.com/serokell/nixpkgs/blob/e68ada3bfc8142ca94526cd5f39fcc58e57b85a4/nixos/modules/services/continuous-integration/buildkite-agents.nix#L258
      # token="$(cat ${toString cfg.tokenPath})"
      # but there is a check that it is a path (starts with a /)
      # long-term, we should probably add a tokenCommand
      tokenPath = "/dev/null <(${getBuildkiteSecrets} | jq -r .AgentToken')";
      # :)

      hooks.environment = ''
        secrets="$(sudo ${getBuildkiteSecrets})"
        export BUILDKITE_API_TOKEN=$(echo "$secrets" | jq -r .APIAccessToken)
        export CACHIX_SIGNING_KEY=$(echo "$secrets" | jq -r .CachixSigningKey)
        unset secrets
      '';
    };

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
            { command = toString getNixopsSecurityCredentials;
              options = [ "NOSETENV" "NOPASSWD" ]; }
          ];
          runAs = "root";
          users = [ "nixops" ];
        }
        {
          commands = [
            { command = toString getBuildkiteSecrets;
              options = [ "NOSETENV" "NOPASSWD" ]; }
          ];
          runAs = "root";
          users = [ "buildkite-agent" ];
        }
      ];
      extraConfig = ''
        Defaults env_keep+=NIX_PATH
      '';

      wheelNeedsPassword = false;
    };
  };

}
