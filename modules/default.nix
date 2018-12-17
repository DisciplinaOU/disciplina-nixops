{
  imports = [
    ./services/disciplina.nix
    ./keys.nix
  ];

  services.nixosManual.enable = false;
  documentation.info.enable = false;
}
