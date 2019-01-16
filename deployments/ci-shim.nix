{
  defaults = {
    fileSystems."/" = { device = "/asdf"; fsType = "btrfs"; };
    boot.loader.systemd-boot.enable = true;
  };
}
