final: previous:

let
  inherit (final) callPackage;
in

{
  nix-with-cachix = callPackage ./nix-with-cachix {};

  nixops = callPackage ./nixops {
    inherit (previous) nixops;
  };
}
