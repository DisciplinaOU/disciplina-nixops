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

      extraConfig = ''
        no-pty=true
      '';

      meta-data = "system=${pkgs.system}";

      package = pkgs.buildkite-agent3;
      runtimePackages = with pkgs; [ bash gnutar nix ];
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
