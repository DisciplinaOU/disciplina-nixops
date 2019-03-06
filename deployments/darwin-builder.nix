{ config, pkgs, ... }:

let
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

    # TODO: doesn't work, buildkite-agent3 doesn't build due to Go impurely
    # depending on CoreFoundation framework. Should be fixed in our Nixpkgs.
    # useSandbox = true;
  };

  nixpkgs.overlays = [ (import ../pkgs) ];

  programs.bash.enable = true;

  services = {
    buildkite-agent = {
      enable = true;
      package = pkgs.buildkite-agent3;

      tags.system = pkgs.system;
      runtimePackages = with pkgs; [ bash gnutar nix-with-cachix ];
      tokenPath = "${secrets}/buildkite-token";
      openssh = {
        publicKeyPath = "${secrets}/buildkite_darwin_rsa.pub";
        privateKeyPath = "${secrets}/buildkite_darwin_rsa";
      };

      # TODO: move to nix-darwin
      extraConfig = ''
        no-pty=true
      '';
    };

    nix-daemon.enable = true;
  };

  # TODO: move to nix-darwin module
  system.activationScripts.postActiation.text = ''
    mkdir -p ${config.users.users.buildkite-agent.home}
    chown -R buildkite-agent:buildkite-agent ${config.users.users.buildkite-agent.home}
    chmod 770 ${config.users.users.buildkite-agent.home}
  '';

  # TODO: move to nix-darwin module
  users = {
    knownGroups = [ "buildkite-agent" ];
    knownUsers = [ "buildkite-agent" ];

    groups.buildkite-agent.gid = 532;
    users.buildkite-agent = {
      uid = 532;
      gid = 532;
    };
  };
}
