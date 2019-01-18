{ pkgs ? import ./pkgs.nix }:

with pkgs;

stdenv.mkDerivation {
  name = "disciplina-nixops";
  nativeBuildInputs = [
    awscli
    nixops
  ];

  NIX_PATH = lib.concatStringsSep ":" [
    "nixpkgs=${pkgs.path}"
    "disciplina=https://github.com/DisciplinaOU/disciplina/archive/master.tar.gz"
    "disciplina-faucet-frontend=https://github.com/DisciplinaOU/disciplina-faucet-frontend/archive/master.tar.gz"
    "disciplina-explorer-frontend=https://github.com/DisciplinaOU/disciplina-explorer-frontend/archive/master.tar.gz"
    "disciplina-validatorcv=https://github.com/DisciplinaOU/disciplina-validatorcv/archive/master.tar.gz"
    "disciplina-nixops=${builtins.toString ./.}"
  ];
}
