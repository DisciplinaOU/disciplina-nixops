# For context, see: https://github.com/cachix/cachix/issues/9
{ stdenv, symlinkJoin, writeShellScriptBin, cachix, jq, nix }:

let
  nix-build-wrapper = writeShellScriptBin "nix-build" ''
    export PATH=${nix}/bin:$PATH

    for path in $(nix-build "$@"); do
      deriver=$(nix show-derivation $path | ${jq}/bin/jq -r "keys | .[0]")

      if [ -n "$CACHIX_NAME" ]; then
        nix-store -qR --include-outputs $deriver | ${cachix}/bin/cachix push $CACHIX_NAME
      fi
    done
  '';
in

symlinkJoin {
  name = "nix-with-cachix";
  paths = [ nix-build-wrapper nix ];
}
