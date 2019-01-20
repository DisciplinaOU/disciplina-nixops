{ pkgs ? import ./pkgs.nix }:

with pkgs;

stdenv.mkDerivation {
  name = "disciplina-nixops";
  nativeBuildInputs = [
    jq
    nixops
  ];

  NIX_PATH = lib.concatStringsSep ":" [
    "nixpkgs=${pkgs.path}"
  ];
}
