{ config, pkgs, ... }:

let
  # Impure, requires MacStadium and some setup:
  # $ ssh-keygen -t ed25519
  secrets = "/Users/administrator";
in

{
  networking.hostName = "disciplina-darwin-builder";

  nix = {
    binaryCaches = [
      "https://disciplina.cachix.org"
    ];

    binaryCachePublicKeys = [
      "disciplina.cachix.org-1:zDeIFV5cu22v04EUuRITz/rYxpBCGKY82x0mIyEYjxE="
    ];

    package = pkgs.nix;

    # Doesn't work because buildkite-agent3 doesn't build due to Go impurely
    # depending on CoreFoundation framework. Should be fixed in our Nixpkgs.
    # useSandbox = true;
  };

  programs.bash.enable = true;

  services = {
    buildkite-agent = {
      enable = true;

      extraConfig = ''
        no-pty=true
      '';

      meta-data = "system=${builtins.currentSystem}";

      openssh = {
        privateKeyPath = "${secrets}/.ssh/id_ed25519";
        publicKeyPath = "${secrets}/.ssh/id_ed25519.pub";
      };

      package = pkgs.buildkite-agent3;
      runtimePackages = with pkgs; [ gnutar nix ];
      tokenPath = "${secrets}/buildkite-token";
    };

    nix-daemon.enable = true;
  };

  system.activationScripts.postActiation.text = ''
    mkdir -p ${config.users.users.buildkite-agent.home}/.cache/nix
    chown -R buildkite-agent:buildkite-agent ${config.users.users.buildkite-agent.home}
    chmod 770 ${config.users.users.buildkite-agent.home}
  '';
}
