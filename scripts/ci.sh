#!/usr/bin/env bash
set -euo pipefail

ROOT=$(realpath "$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )/..")
TMPD="$(mktemp -d)"
NIXOPS_STATE="$TMPD/state.nixops"
export NIXOPS_STATE

cd "$ROOT"
nix-shell --run 'nixops create deployments/cluster.nix; nixops deploy --build-only --show-trace; nixops destroy --confirm; nixops delete --force'

function cleanup {
  rm -f "$NIXOPS_STATE"
}

trap finish EXIT
