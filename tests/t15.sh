#!/bin/bash
# T15 — eth_estimateGas on both sides (#2516).
# Usage: t15.sh pre|post
source "$(dirname "$0")/gas2500x-lib.sh"
begin_case "T15" "eth_estimateGas on both sides (${1:-?} side)"

side=${1:-pre}
fork_side "$side"

S1=$(addr_of TXGEN_KEY_1)
est=$(rpc3 eth_estimateGas "[{\"from\":\"$(addr_of TXGEN_KEY_2)\",\"to\":\"$S1\",\"value\":\"0x1\"}]")
[ "$est" = "null" ] && fail_case "estimateGas returned null"
gas=$(hex2dec "$(printf '%s' "$est" | jq -r .)")
[ "$gas" = "21000" ] || fail_case "estimate=$gas, expected 21000"
pass_case "estimateGas=$gas (${side} side)"
