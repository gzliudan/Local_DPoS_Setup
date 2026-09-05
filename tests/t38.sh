#!/bin/bash
# T38 — eth_maxPriorityFeePerGas suggests a tip below the post-fork tier
# price (625 gwei), #2516. (The pre-fork half of this check is T12.)
source "$(dirname "$0")/gas2500x-lib.sh"
begin_case "T38" "eth_maxPriorityFeePerGas suggests a tip below the tier price (post-fork tier)" 0.0

# no guard: the runner schedules this well after the fork

tip=$(hex2dec "$(rpc0 eth_maxPriorityFeePerGas | jq -r .)") || fail_case "RPC error"
[ "$tip" -lt "$GAS2500_WEI" ] || fail_case "tip=$tip not below tier price $GAS2500_WEI"
pass_case "tip suggestion=$tip wei (< $GAS2500_WEI)"
