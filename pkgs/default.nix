final: previous:

let
  inherit (final) callPackage;
in

{
  aws-rotate-key = previous.aws-rotate-key.overrideAttrs (super: {
    patches = (super.patches or []) ++ [(final.fetchpatch {
      url = https://github.com/serokell/aws-rotate-key/commit/5606b4c2e2a395560618126a3c1e2afaf1c0d2f3.patch;
      sha256 = "0g120qbdg92lf57jw8wwc515gk4v4k0z569c33mb25rzkarlsjrd";
    })];
  });

  nix-with-cachix = callPackage ./nix-with-cachix {};

  nixops = callPackage ./nixops {
    inherit (previous) nixops;
  };
}
