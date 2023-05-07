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
  inherit (import <custodial-wallet-api/deploy.nix> {})
    custodial-wallet-api nodejs-16_x;

  # disciplina-faucet-frontend = callPackage <disciplina-faucet-frontend/release.nix> {};
  # disciplina-explorer-frontend = callPackage <disciplina-explorer-frontend/release.nix> {};
  disciplina-validatorcv = import <disciplina-validatorcv> {};
  disciplina-educator-spa = import <disciplina-educator-spa> {};
}
