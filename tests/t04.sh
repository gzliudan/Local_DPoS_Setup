#!/bin/bash
# T04 — eth_maxPriorityFeePerGas suggests a tip below the pre-fork tier
# price (12.5 gwei), #2516. (The post-fork half of this check is T38.)
source "$(dirname "$0")/gas2500x-lib.sh"
begin_case "T04" "verify eth_maxPriorityFeePerGas suggests a tip below the tier price (pre-fork tier)" 0.0

require_pre_fork "pre side missed the window"

tip=$(hex2dec "$(rpc0 eth_maxPriorityFeePerGas | jq -r .)") || fail_case "RPC error"
[ "$tip" -lt "$GAS50_WEI" ] || fail_case "tip=$tip not below tier price $GAS50_WEI"
pass_case "tip suggestion=$tip wei (< $GAS50_WEI)"
