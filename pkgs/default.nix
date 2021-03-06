final: previous:

let
  inherit (final) callPackage fetchpatch;

in {
  # cachix broken on nixpkgs: https://github.com/cachix/cachix/pull/149
  cachix = callPackage ./cachix.nix {};
  nix-with-cachix = callPackage ./nix-with-cachix {};

  nixops = callPackage ./nixops {
    inherit (previous) nixops;
  };

  inherit (import <disciplina/release.nix> {})
    disciplina-config disciplina-data disciplina pdf-generator-xelatex;
  disciplina-faucet-frontend = callPackage <disciplina-faucet-frontend/release.nix> {};
  disciplina-explorer-frontend = callPackage <disciplina-explorer-frontend/release.nix> {};
  disciplina-validatorcv = callPackage <disciplina-validatorcv/release.nix> {};
  disciplina-educator-spa = callPackage <disciplina-educator-spa/release.nix> {};
}
