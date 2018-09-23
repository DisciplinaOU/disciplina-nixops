# For context, see: https://github.com/cachix/cachix/issues/9
{ stdenv, symlinkJoin, writeShellScriptBin, cachix, jq, nix }:

let
  nix-build-wrapper = writeShellScriptBin "nix-build" ''
    export PATH=${nix}/bin:$PATH

    for path in $(nix-build "$@"); do
      deriver=$(nix show-derivation $path | ${jq}/bin/jq -r 'keys | .[0]')
      outputs=$(mktemp)

      for requisite in $(nix-store -qR --include-outputs $deriver); do
        if [ "$(nix-store -qd $requisite)" != "unknown-deriver" ]; then
          echo $requisite >> $outputs
        fi
      done

      for requisite in $(nix-store -qR $deriver); do
        if [ "$(nix-store -qd $requisite)" != "unknown-deriver" ]; then
          echo $requisite >> $outputs
        fi
      done

      if [ -n "$CACHIX_NAME" ]; then
        ${cachix}/bin/cachix push $CACHIX_NAME < $outputs
      fi

      rm $outputs
    done
  '';
in

symlinkJoin {
  name = "nix-with-cachix";
  paths = [ nix-build-wrapper nix ];
}
