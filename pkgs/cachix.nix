{ haskell, pkgs }:
haskell.lib.justStaticExecutables
  ((import "${builtins.fetchTarball {
    url = https://github.com/cachix/cachix/archive/v0.1.3.tar.gz;
    sha256 = "09hxrsjmgji2ckxchfskb9km1zqb04sk6kb60p5vqwlvpzy517mb";
  }}/stack2nix.nix" {
    inherit pkgs;
    compiler = haskell.packages.ghc844;
  }).cachix)
