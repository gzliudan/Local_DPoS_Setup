#!/bin/bash
# T10 — eth_gasPrice on both sides of the fork (#2516).
# Usage: t10.sh pre|post
source "$(dirname "$0")/gas2500x-lib.sh"
begin_case "T10" "eth_gasPrice across the fork (${1:-?} side)"

side=${1:-pre}
gp=$(hex2dec "$(rpc0 eth_gasPrice | jq -r .)")
case "$side" in
pre)  [ "$gp" = "$GAS50_WEI" ]   || fail_case "pre-fork gasPrice=$gp, expected $GAS50_WEI" ;;
post) [ "$gp" = "$GAS2500_WEI" ] || fail_case "post-fork gasPrice=$gp, expected $GAS2500_WEI" ;;
*)    fail_case "usage: $0 pre|post" ;;
esac
pass_case "gasPrice=$gp wei"
