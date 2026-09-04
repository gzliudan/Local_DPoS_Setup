#!/bin/bash
# T11 — eth_maxPriorityFeePerGas on both sides of the fork (#2516).
# Usage: t11.sh pre|post
source "$(dirname "$0")/gas2500x-lib.sh"
begin_case "T11" "eth_maxPriorityFeePerGas across the fork (${1:-?} side)"

side=${1:-pre}
if [ "$side" = "pre" ]; then
    h=$(head3)
    [ "$h" -lt "$FORK_BLOCK" ] || skip_case "head $h >= fork $FORK_BLOCK; pre side missed the window"
fi
tip=$(hex2dec "$(rpc0 eth_maxPriorityFeePerGas | jq -r .)") || fail_case "RPC error"
case "$side" in
pre)  cap=$GAS50_WEI ;;
post) cap=$GAS2500_WEI ;;
*)    fail_case "usage: $0 pre|post" ;;
esac
[ "$tip" -lt "$cap" ] || fail_case "tip=$tip not below tier price $cap"
pass_case "tip suggestion=$tip wei (< $cap)"
