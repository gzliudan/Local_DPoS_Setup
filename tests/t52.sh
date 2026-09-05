#!/bin/bash
# T52 — eth_estimateGas returns the standard 21000 post-fork (read-only
# probe), #2516. (The pre-fork half of this check is T15.)
source "$(dirname "$0")/gas2500x-lib.sh"
begin_case "T52" "eth_estimateGas works (post-fork tier)"

# no guard: the runner schedules this well after the fork

S1=$(addr_of TXGEN_KEY_1)
est=$(rpc3 eth_estimateGas "[{\"from\":\"$(addr_of TXGEN_KEY_2)\",\"to\":\"$S1\",\"value\":\"0x1\"}]")
[ "$est" = "null" ] && fail_case "estimateGas returned null"
gas=$(hex2dec "$(printf '%s' "$est" | jq -r .)")
[ "$gas" = "21000" ] || fail_case "estimate=$gas, expected 21000"
pass_case "estimateGas=$gas"
