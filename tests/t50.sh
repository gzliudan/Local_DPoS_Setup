#!/bin/bash
# T50 — the tier-aware default gas price on the post-fork tier (625 gwei):
# P3's transfer is signed locally with NO gas price, #2516.
# (The pre-fork half of this check is T13; P3 = pn3's own account,
# PRIVATE_KEY_3.)
source "$(dirname "$0")/gas2500x-lib.sh"
begin_case "T50" "the tier-aware default gas price (post-fork tier)"

# no guard: the runner schedules this well after the fork

P3_TO=$(addr_of TXGEN_KEY_1)
hash=$(_cast_send "$RPC3" PRIVATE_KEY_3 "$P3_TO" 1 "" "" --async 2>/dev/null)
case "$hash" in 0x*) ;; *) fail_case "send rejected" ;; esac

eff=$(hex2dec "$(receipt_field "$hash" effectiveGasPrice)")
[ "$eff" = "$GAS2500_WEI" ] || fail_case "effectiveGasPrice=$eff, expected $GAS2500_WEI"
pass_case "default-price tx sealed at $eff wei"
