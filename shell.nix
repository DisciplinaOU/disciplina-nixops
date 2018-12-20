{ pkgs ? import ./pkgs.nix
, env ? "staging" }:

with pkgs;

stdenv.mkDerivation {
  name = "disciplina-nixops";
  nativeBuildInputs = [
    awscli
    git-crypt
    nixops
    sqlite
  ];

  AWS_ACCESS_KEY_ID = "default";
  AWS_SHARED_CREDENTIALS_FILE = "${toString ./.}/keys/${env}/aws-credentials";

  DISCPLINA_ENV = env; # Fancy way to share this variable with nixops
  NIX_PATH = lib.concatStringsSep ":" [
    "nixpkgs=${pkgs.path}"
    "disciplina=https://github.com/DisciplinaOU/disciplina/archive/master.tar.gz"
    "disciplina-faucet-frontend=https://github.com/DisciplinaOU/disciplina-faucet-frontend/archive/master.tar.gz"
    "disciplina-explorer-frontend=https://github.com/DisciplinaOU/disciplina-explorer-frontend/archive/master.tar.gz"
    "disciplina-validatorcv=https://github.com/DisciplinaOU/disciplina-validatorcv/archive/master.tar.gz"
    "disciplina-validatorcv=https://github.com/DisciplinaOU/disciplina-validatorcv/archive/release/0.1.0.tar.gz"
    "local=${builtins.toString ./.}"
  ];
}
