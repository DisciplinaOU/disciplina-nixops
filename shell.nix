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
    "nixpkgs=${toString pkgs.path}"
    "nixpkgs-overlays=${overlay}"
  ];
}
