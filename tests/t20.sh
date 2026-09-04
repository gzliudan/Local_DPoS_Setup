#!/bin/bash
# T20 — at-floor execution on the new tier: S1 sends at exactly 625 gwei.
source "$(dirname "$0")/gas2500x-lib.sh"
begin_case "T20" "at-floor execution on the new tier (625 gwei)"

head=$(head3)
[ "$head" -ge "$FORK_BLOCK" ] || fail_case "head $head < fork $FORK_BLOCK"

S1_TO=$(addr_of TXGEN_KEY_2)
hash=$(send_from TXGEN_KEY_1 "$S1_TO" 1 "$GAS2500_WEI")
[ -n "$hash" ] || fail_case "send rejected"

status=$(hex2dec "$(receipt_field "$hash" status)")
eff=$(hex2dec "$(receipt_field "$hash" effectiveGasPrice)")
[ "$status" = "1" ] || fail_case "status=$status"
[ "$eff" = "$GAS2500_WEI" ] || fail_case "effectiveGasPrice=$eff != $GAS2500_WEI"
pass_case "sealed at $eff wei (block $(hex2dec "$(receipt_field "$hash" blockNumber)"))"
