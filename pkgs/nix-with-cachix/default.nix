# For context, see: https://github.com/cachix/cachix/issues/9
{ stdenv, runCommand, symlinkJoin, writeShellScriptBin, cachix, jq, nix }:

let
  nix-build-wrapper = writeShellScriptBin "nix-build" ''
    set -eou pipefail

    export PATH=${nix}/bin:$PATH
    output=$(nix-build "$@")

    for path in "$output"; do
      deriver=$(nix show-derivation $path | ${jq}/bin/jq -r "keys | .[0]")

      if [ -n "$CACHIX_NAME" ]; then
        nix-store -qR --include-outputs $deriver | ${cachix}/bin/cachix push "$CACHIX_NAME"
      fi
    done
  '';

  nix-shell-symlink = runCommand "nix-shell" {} ''
    mkdir -p $out/bin
    ln -s ${nix}/bin/nix-build $out/bin/nix-shell
  '';
in

symlinkJoin {
  name = "nix-with-cachix";
  paths = [ nix-build-wrapper nix-shell-symlink nix ];
}
