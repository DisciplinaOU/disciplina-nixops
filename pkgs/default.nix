final: previous:

let
  inherit (final) callPackage fetchpatch;

in {
  nginxStable = previous.nginxStable.overrideAttrs (super: {
    patches = (super.patches or []) ++ [(fetchpatch {
      url = https://gitlab.com/yegortimoshenko/patches/raw/166f4fa4d90a7dca5c9eeeda2aaf2f1d4b841e87/nginx/nix-etag-1.15.4.patch;
      sha256 = "09wi3zgizr0vgy24pkqbswr1318yxihr7jdjbl29q44glsjqg5rb";
    })];
  });

  cachix = callPackage ./cachix.nix {};
  nix-with-cachix = callPackage ./nix-with-cachix {};

  nixops = callPackage ./nixops {
    inherit (previous) nixops;
  };

  # inherit (import <disciplina/release.nix> {}) disciplina-config disciplina;
  # disciplina-faucet-frontend = callPackage <disciplina-faucet-frontend/release.nix> {};
  # disciplina-explorer-frontend = callPackage <disciplina-explorer-frontend/release.nix> {};
  # disciplina-validatorcv = callPackage <disciplina-validatorcv/release.nix> {};
}
