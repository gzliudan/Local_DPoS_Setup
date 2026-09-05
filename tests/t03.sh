#!/bin/bash
# T03 — eth_gasPrice reports the pre-fork tier price (12.5 gwei), #2516.
# (The post-fork half of this check is T37.)
source "$(dirname "$0")/gas2500x-lib.sh"
begin_case "T03" "eth_gasPrice reports the tier price (pre-fork tier)" 0.0

require_pre_fork "pre side missed the window"

gp=$(hex2dec "$(rpc0 eth_gasPrice | jq -r .)")
[ "$gp" = "$GAS50_WEI" ] || fail_case "gasPrice=$gp, expected $GAS50_WEI"
pass_case "gasPrice=$gp wei"
