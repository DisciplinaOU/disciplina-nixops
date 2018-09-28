final: previous:

let
  inherit (final) callPackage;
in

{
  aws-rotate-key = previous.aws-rotate-key.overrideAttrs (super: {
    patches = (super.patches or []) ++ [(final.fetchpatch {
      url = https://github.com/serokell/aws-rotate-key/commit/5606b4c2e2a395560618126a3c1e2afaf1c0d2f3.patch;
      sha256 = "0vpi10p6q2yz2j5j6ird9w4bcr8bagh1c4bqm2v2rmymbbwx46ai";
    })];
  });

  nix-with-cachix = callPackage ./nix-with-cachix {};

  nixops = callPackage ./nixops {
    inherit (previous) nixops;
  };
}
