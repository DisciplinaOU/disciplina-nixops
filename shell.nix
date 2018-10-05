{ pkgs ? import ./pkgs.nix, env ? "staging" }:

with import pkgs.path {
  overlays = [ (import ./pkgs) ];
};

let
  overlay = runCommand "nixpkgs-overlays" {} ''
    mkdir -p $out && ln -s ${toString ./.}/pkgs $_
  '';
in

stdenv.mkDerivation {
  name = "disciplina-nixops";
  nativeBuildInputs = [ aws-rotate-key git-crypt nixops sqlite ];

  AWS_ACCESS_KEY_ID = "default";
  AWS_SHARED_CREDENTIALS_FILE = "${toString ./.}/keys/${env}/aws-credentials";

  NIX_PATH = lib.concatStringsSep ":" [
    "nixpkgs=${pkgs.path}"
    "nixpkgs-overlays=${overlay}"
    "disciplina=https://github.com/DisciplinaOU/disciplina/archive/master.tar.gz"
    "disciplina-faucet-frontend=https://github.com/DisciplinaOU/disciplina-faucet-frontend/archive/master.tar.gz"
    "disciplina-explorer-frontend=https://github.com/DisciplinaOU/disciplina-explorer-frontend/archive/master.tar.gz"
  ];
}
