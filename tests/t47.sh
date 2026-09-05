#!/bin/bash
# T47 — eth_gasPrice reports the post-fork tier price (625 gwei), #2516.
# (The pre-fork half of this check is T10.)
source "$(dirname "$0")/gas2500x-lib.sh"
begin_case "T47" "eth_gasPrice reports the tier price (post-fork tier)"

# no guard: the runner schedules this well after the fork

gp=$(hex2dec "$(rpc0 eth_gasPrice | jq -r .)")
[ "$gp" = "$GAS2500_WEI" ] || fail_case "gasPrice=$gp, expected $GAS2500_WEI"
pass_case "gasPrice=$gp wei"
