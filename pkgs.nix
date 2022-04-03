let
  sources = import ./nix/sources.nix;
  haskellNix = import sources.haskellNix {};
  pkgs = import haskellNix.sources.nixpkgs-unstable haskellNix.nixpkgsArgs;
in
  pkgs.extend (import ./pkgs)
