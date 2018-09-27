final: previous:

let
  inherit (final) callPackage;
in

{
  aws-rotate-key = previous.aws-rotate-key.overrideAttrs (super: {
    src = fetchGit {
      url = "https://github.com/serokell/aws-rotate-key";
      rev = "5606b4c2e2a395560618126a3c1e2afaf1c0d2f3";
    };
  });

  nix-with-cachix = callPackage ./nix-with-cachix {};

  nixops = callPackage ./nixops {
    inherit (previous) nixops;
  };
}
