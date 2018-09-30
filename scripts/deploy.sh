#!/usr/bin/env bash
set -euo pipefail

declare -a NIXOPS_OPTIONS DEPLOY_FIRST
NIXOPS_OPTIONS=( -d disciplina --show-trace )
DEPLOY_FIRST=( witness0 witness-load-balancer )
SLEEP='3m'

nixops deploy "${NIXOPS_OPTIONS[@]}" --include "${DEPLOY_FIRST[@]}"
sleep "$SLEEP"
nixops deploy "${NIXOPS_OPTIONS[@]}" --exclude "${DEPLOY_FIRST[@]}"
