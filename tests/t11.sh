#!/bin/bash
# T11 — eth_maxPriorityFeePerGas on both sides of the fork (#2516).
# Usage: t11.sh pre|post
source "$(dirname "$0")/gas2500x-lib.sh"
begin_case "T11" "eth_maxPriorityFeePerGas across the fork (${1:-?} side)"

side=${1:-pre}
fork_side "$side"
cap=$(tier_for "$side")

tip=$(hex2dec "$(rpc0 eth_maxPriorityFeePerGas | jq -r .)") || fail_case "RPC error"
[ "$tip" -lt "$cap" ] || fail_case "tip=$tip not below tier price $cap"
pass_case "tip suggestion=$tip wei (< $cap)"
