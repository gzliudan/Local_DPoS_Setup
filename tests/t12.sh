#!/bin/bash
# T12 — eth_getBlockByNumber baseFeePerGas on both sides of the fork (#2516).
# Usage: t12.sh pre|post
source "$(dirname "$0")/gas2500x-lib.sh"
begin_case "T12" "eth_getBlockByNumber baseFeePerGas (${1:-?} side)"

side=${1:-pre}
if [ "$side" = "pre" ]; then
    h=$(head3)
    [ "$h" -lt "$FORK_BLOCK" ] || skip_case "head $h >= fork $FORK_BLOCK; pre side missed the window"
fi
bf=$(hex2dec "$(rpc3 eth_getBlockByNumber "[\"latest\", false]" | jq -r .baseFeePerGas)")
case "$side" in
pre)  [ "$bf" = "$GAS50_WEI" ]   || fail_case "latest baseFee=$bf, expected $GAS50_WEI" ;;
post)
    [ "$bf" = "$GAS2500_WEI" ] || fail_case "latest baseFee=$bf, expected $GAS2500_WEI"
    bf89=$(hex2dec "$(rpc3 eth_getBlockByNumber "[\"$(printf '0x%x' $((FORK_BLOCK - 1)))\", false]" | jq -r .baseFeePerGas)")
    bf90=$(hex2dec "$(rpc3 eth_getBlockByNumber "[\"$(printf '0x%x' "$FORK_BLOCK")\", false]" | jq -r .baseFeePerGas)")
    [ "$bf89" = "$GAS50_WEI" ] || fail_case "block $((FORK_BLOCK - 1)) baseFee=$bf89"
    [ "$bf90" = "$GAS2500_WEI" ] || fail_case "block $FORK_BLOCK baseFee=$bf90"
    ;;
*)    fail_case "usage: $0 pre|post" ;;
esac
pass_case "baseFeePerGas=$bf wei (step 89→90 visible)"
