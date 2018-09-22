final: previous:

let
  inherit (final) callPackage;
in

{
  nixops = callPackage ./nixops {};
}
