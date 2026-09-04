#!/bin/bash
# T10 — eth_gasPrice on both sides of the fork (#2516).
# Usage: t10.sh pre|post
source "$(dirname "$0")/gas2500x-lib.sh"
begin_case "T10" "eth_gasPrice across the fork (${1:-?} side)"

side=${1:-pre}
fork_side "$side"

gp=$(hex2dec "$(rpc0 eth_gasPrice | jq -r .)")
[ "$gp" = "$(tier_for "$side")" ] || \
    fail_case "$side-fork gasPrice=$gp, expected $(tier_for "$side")"
pass_case "gasPrice=$gp wei"
