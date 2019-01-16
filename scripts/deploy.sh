#!/usr/bin/env nix-shell
#! nix-shell ../shell.nix -i bash
#
# This script deploys a cluster in 3 stages:
# - Base network
# - Route associations
# - Machines
#
# Route associations fail to deploy together with the base network due to some
# of the resource IDs being passed as string arguments rather than nix resource
# declarations. They have to be deployed in a second pass.
#
# Once all resources are up, we can deploy our machines.

set -exuo pipefail

declare -a NIXOPS_OPTIONS MACHINES STAGE2
NIXOPS_OPTIONS=( --show-trace )
MACHINES=( balancer educator witness0 witness1 witness2 witness3 )
STAGE2=( a-assoc b-assoc c-assoc )
DEP="${1:-disciplina}"

nixops deploy -d "$DEP" "${NIXOPS_OPTIONS[@]}" --exclude "${MACHINES[@]}" "${STAGE2[@]}"
nixops deploy -d "$DEP" "${NIXOPS_OPTIONS[@]}" --exclude "${MACHINES[@]}"
nixops deploy -d "$DEP" "${NIXOPS_OPTIONS[@]}"
