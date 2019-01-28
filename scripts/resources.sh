#!/usr/bin/env nix-shell
#!nix-shell -i bash -p bash jq
# shellcheck shell=bash

#
# Usage: ./resources.sh <source_deployment> <target_deployment>
#
# This script reads the resource IDs from one deployment and feeds them
# to another deployment via `nixops set-args`.
#
# We pull these values from the `deployer` network:
#
# - VPC ID
# - VPC CIDR block
# - Route Table ID
#
# These resources are necessary to link an independent deployment into the same
# network.

set -euo pipefail
[[ -n ${DEBUG:-} ]] && set -x

################################################################################
################################################################################


from="$1"
to="$2"

[ -n "$from" -o -n "$to" ] || {
  echo >&2 "Usage: $0 <source_deployment> <target_deployment>"
  exit 1
}

state="$(nixops export -d "$from")"
shared_vpc_id=$(echo "$state"   | jq -r ".[].resources[\"shared-vpc\"].vpcId")
shared_vpc_cidr=$(echo "$state" | jq -r ".[].resources[\"shared-vpc\"].cidrBlock")
route_table_id=$(echo "$state"  | jq -r ".[].resources[\"route-table\"].routeTableId")

nixops set-args -d "$to" --argstr vpcId        "$shared_vpc_id"
nixops set-args -d "$to" --argstr vpcCidr      "$shared_vpc_cidr"
nixops set-args -d "$to" --argstr routeTableId "$route_table_id"
