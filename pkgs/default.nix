final: previous:

let
  inherit (final) callPackage fetchpatch;
in

{
  aws-rotate-key = previous.aws-rotate-key.overrideAttrs (super: {
    patches = (super.patches or []) ++ [(fetchpatch {
      url = https://github.com/Fullscreen/aws-rotate-key/commit/5606b4c2e2a395560618126a3c1e2afaf1c0d2f3.patch;
      sha256 = "0vpi10p6q2yz2j5j6ird9w4bcr8bagh1c4bqm2v2rmymbbwx46ai";
    })];
  });

  nginxStable = previous.nginxStable.overrideAttrs (super: {
    patches = (super.patches or []) ++ [(fetchpatch {
      url = https://gitlab.com/yegortimoshenko/patches/raw/166f4fa4d90a7dca5c9eeeda2aaf2f1d4b841e87/nginx/nix-etag-1.15.4.patch;
      sha256 = "09wi3zgizr0vgy24pkqbswr1318yxihr7jdjbl29q44glsjqg5rb";
    })];
  });

  nix-with-cachix = callPackage ./nix-with-cachix {};

  nixops = callPackage ./nixops {
    inherit (previous) nixops;
  };
}
