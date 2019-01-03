#!/usr/bin/env nix-shell
#! nix-shell ../shell.nix -i bash
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
set -euo pipefail
[[ -n ${DEBUG:-} ]] && set -x

from=${1:-staging}
to=${2:-disciplina}
mode=${3:-local}

DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" >/dev/null && pwd )"
SFILE="$DIR/../state/deployer.nixops"

json="$(nixops export -s "$SFILE" -d "$from")"
shared_vpc_id=$(echo "$json" | jq -r ".[].resources[\"shared-vpc\"].vpcId")
shared_vpc_cidr=$(echo "$json" | jq -r ".[].resources[\"shared-vpc\"].cidrBlock")
route_table_id=$(echo "$json" | jq -r ".[].resources[\"route-table\"].routeTableId")

if [[ $mode == local ]]; then
    nixops set-args -d "$to" --argstr vpcId "$shared_vpc_id"
    nixops set-args -d "$to" --argstr vpcCidr "$shared_vpc_cidr"
    nixops set-args -d "$to" --argstr routeTableId "$route_table_id"

elif [[ $mode == remote ]]; then
    echo "$shared_vpc_id" >| shared_vpc_id
    echo "$shared_vpc_cidr" >| shared_vpc_cidr
    echo "$route_table_id" >| route_table_id

    nixops scp -s "$SFILE" -d "$from" builder shared_vpc_id /var/lib/nixops/shared_vpc_id
    nixops scp -s "$SFILE" -d "$from" builder shared_vpc_cidr /var/lib/nixops/shared_vpc_cidr
    nixops scp -s "$SFILE" -d "$from" builder route_table_id /var/lib/nixops/route_table_id

fi
