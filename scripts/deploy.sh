#!/usr/bin/env nix-shell
#! nix-shell ../shell.nix -i bash
set -exuo pipefail

declare -a NIXOPS_OPTIONS DEPLOY_FIRST
NIXOPS_OPTIONS=( -d disciplina --show-trace )
DEPLOY_FIRST=( witness0 balancer )
SLEEP='3m'

nixops deploy "${NIXOPS_OPTIONS[@]}" --include "${DEPLOY_FIRST[@]}"
sleep "$SLEEP"
nixops deploy "${NIXOPS_OPTIONS[@]}" --exclude "${DEPLOY_FIRST[@]}"
