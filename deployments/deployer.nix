{ region ? "eu-central-1"
, domain
, env
, pkgs0 ? import ../pkgs.nix
, ...}:

let
  pkgs = if env != "bootstrap" then pkgs0 else pkgs0.extend
    (self: super: {
      nix = super.nix.overrideDerivation (_: {
        patches = null;
        doInstallCheck = true;
      });
    });

  inherit (pkgs) lib;
  wheelUsers = [ "dboulas" "flyingleafe" ];
  nixopsUsers = wheelUsers ++ [ ];
  expandUser = _name: keys: {
    extraGroups = [ "systemd-journal" ]
    ++ (lib.optional (builtins.elem _name wheelUsers) "wheel")
    ++ (lib.optional (builtins.elem _name nixopsUsers) "nixops");
    isNormalUser = true;
    openssh.authorizedKeys.keys = keys;
  };

  getNixopsSecurityCredentials = pkgs.writeScript "getNixopsSecurityCredentials" ''
    #!${pkgs.bash}/bin/bash
    ${pkgs.curl}/bin/curl --silent --show-error \
      http://169.254.169.254/latest/meta-data/iam/security-credentials/serokell-nixops
  '';

  buildkiteAgentName = "default";
  buildkiteAgentUserName = "buildkite-agent-${buildkiteAgentName}";

  nixopsWrapper =
  let
    git = "${pkgs.git}/bin/git -c user.name=nixops -c user.email=";
  in pkgs.writeShellScriptBin "nixops" ''
    sudo NIXOPS_DEPLOYMENT="$NIXOPS_DEPLOYMENT" -u nixops ${
      pkgs.writeShellScriptBin "nixopsWrapper" ''
      set -euo pipefail

      [ "$(whoami)" = "nixops" ] || { echo Please run with sudo -u nixops; exit 1; }

      # Download AWS credentials using the serokell-nixops instance profile and
      # forward them to nixops
      key_json="$(sudo ${getNixopsSecurityCredentials})"

      mkdir -pm 700 /var/lib/nixops/.aws
      cat > /var/lib/nixops/.aws/credentials <<EOF
      [default]
      aws_access_key_id=$(echo "$key_json" | ${pkgs.jq}/bin/jq -r .AccessKeyId)
      aws_secret_access_key=$(echo "$key_json" | ${pkgs.jq}/bin/jq -r .SecretAccessKey)
      aws_session_token=$(echo "$key_json" | ${pkgs.jq}/bin/jq -r .Token)
      EOF

      AWS_ACCESS_KEY_ID=default ${pkgs.nixops}/bin/nixops "$@"
      rv=$?

      cd /var/lib/nixops/.nixops
      [ -e .git ] || {
        ${git} init -q
        ${git} commit --allow-empty -qm "initial commit"
      }

      ${git} add .
      ${git} diff-index --quiet HEAD || \
        ${git} commit -qm "nixops $*"
      exit $rv
    ''}/bin/nixopsWrapper "$@"
  '';

in {
  network.description = "Disciplina - shared infra";
  require = [ ./shared-resources.nix ];

  deployer = { config, name, resources, ... }: {
    imports = [ ../modules ];

    # boot.kernelPackages = pkgs.linuxPackages_4_9;

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
        [ ssh-public-sg.name mosh-public-sg.name ];
    };

    deployment.route53 = {
      usePublicDNSName = true;
      hostName = "${name}.${domain}";
    };

    documentation.enable = false;

    environment.systemPackages = with pkgs; [ git nixopsWrapper ];

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

      nixPath = [
        "nixpkgs=${pkgs.path}"
        "/nix/var/nix/profiles/per-user/root/channels"
      ];
    };

    nixpkgs.pkgs = pkgs;

    awskeys =
    let
      buildkiteKeyCommon = {
        inherit region;
        user = buildkiteAgentUserName;
        services = [ buildkiteAgentUserName ];
        secretId = "production/disciplina/buildkite";
      };
    in {
      agent-token        = buildkiteKeyCommon // { key = "AgentToken"; };
      api-access-token   = buildkiteKeyCommon // { key = "APIAccessToken"; };
      cachix-signing-key = buildkiteKeyCommon // { key = "CachixSigningKey"; };
      buildkite-ssh-key  = buildkiteKeyCommon // { key = "BuildkiteSSHKeys.${buildkiteAgentName}"; };
    };

    services.buildkite-agents.${buildkiteAgentName} = let keys = config.awskeys; in {
      enable = env != "bootstrap";

      runtimePackages = with pkgs; [ bash gnutar nix-with-cachix jq ];

      tags.hostname = config.networking.hostName;
      tags.system = pkgs.system;

      tokenPath = toString keys.agent-token;
      sshKeyPath = toString keys.buildkite-ssh-key;

      hooks.environment = ''
        export BUILDKITE_API_TOKEN=$(cat ${toString keys.api-access-token})
        export CACHIX_SIGNING_KEY=$(cat ${toString keys.cachix-signing-key})
        export CACHIX_NAME=disciplina
        unset secrets
      '';
    };

    # Enables `mosh` for more comfortable connection to deployer via SSH
    programs.mosh.enable = true;

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
      ];
      extraConfig = ''
        Defaults env_keep+=NIX_PATH
      '';

      wheelNeedsPassword = false;
    };

    system.activationScripts.nixops = lib.stringAfter [ "users" "groups" ] ''
      chmod g+rwxs ${config.users.users.nixops.home}
      ${pkgs.acl}/bin/setfacl -m d:g:nixops:rwX ${config.users.users.nixops.home}
    '';
  };
}
