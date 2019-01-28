#!/usr/bin/env bash

#
# Usage: ./deploy.sh <deployment>
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

################################################################################
################################################################################


dep="$1"

[ -n "$dep" ] || {
  echo >&2 "Usage: $0 <deployment>"
  exit 1
}
export NIXOPS_DEPLOYMENT="$dep"

declare -a NIXOPS_OPTIONS MACHINES STAGE2
NIXOPS_OPTIONS=( --show-trace )
MACHINES=( balancer educator witness0 witness1 witness2 witness3 )
STAGE2=( a-assoc b-assoc c-assoc )

nixops deploy "${NIXOPS_OPTIONS[@]}" --exclude "${MACHINES[@]}" "${STAGE2[@]}"
nixops deploy "${NIXOPS_OPTIONS[@]}" --exclude "${MACHINES[@]}"
nixops deploy "${NIXOPS_OPTIONS[@]}"
