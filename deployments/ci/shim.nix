{
  defaults = {
    fileSystems."/" = { device = "/asdf"; fsType = "btrfs"; };
    boot.loader.systemd-boot.enable = true;
    networking.privateIPv4 = "1.2.3.4";
    nixpkgs.overlays = [ (import ./overlay.nix) ];
  };
}
