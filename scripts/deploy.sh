#!/usr/bin/env bash
declare -a NIXOPS_OPTIONS DEPLOY_FIRST
NIXOPS_OPTIONS=( '-I ssh-key=/var/lib/nixops/.ssh/id_rsa' )
DEPLOY_FIRST=( witness0 witness-load-balancer )
SLEEP='15m'

nixops deploy "${NIXOPS_OPTIONS[@]}" --include "${DEPLOY_FIRST[@]}"
sleep "$SLEEP"
nixops deploy "${NIXOPS_OPTIONS[@]}" --exclude "${DEPLOY_FIRST[@]}"
