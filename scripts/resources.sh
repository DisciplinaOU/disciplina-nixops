#!/usr/bin/env nix-shell
#! nix-shell -i bash -p bash jq
# shellcheck shell=bash

##
# This file reads the resource IDs from one deployment and feeds them to
# another deployment via `nixops set-args`.
#
# Currently, we pull these values from the `deployer` network:
# - VPC ID
# - VPC CIDR block
# - Route Table ID
#
# These resources are necessary to link an independent deployment into the same
# network.
#
# E.g. to copy resources from the "deployer" to the "staging" cluster:
# $ ./resources.sh deployer staging

set -euo pipefail
[[ -n ${DEBUG:-} ]] && set -x

from=${1:-staging}
to=${2:-disciplina}

json="$(nixops export -d "$from")"
shared_vpc_id=$(echo "$json"   | jq -r ".[].resources[\"shared-vpc\"].vpcId")
shared_vpc_cidr=$(echo "$json" | jq -r ".[].resources[\"shared-vpc\"].cidrBlock")
route_table_id=$(echo "$json"  | jq -r ".[].resources[\"route-table\"].routeTableId")

# Write IDs to local deployment
nixops set-args -d "$to" --argstr vpcId        "$shared_vpc_id"
nixops set-args -d "$to" --argstr vpcCidr      "$shared_vpc_cidr"
nixops set-args -d "$to" --argstr routeTableId "$route_table_id"
