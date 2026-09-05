#!/bin/bash
# T29 — at-floor execution on the new tier: S1 sends at exactly 625 gwei.
source "$(dirname "$0")/gas2500x-lib.sh"
begin_case "T29" "seal a tx at the new floor (625 gwei)" 2.1

require_post_fork

S1_TO=$(addr_of TXGEN_KEY_2)
hash=$(send_from TXGEN_KEY_1 "$S1_TO" 1 "$GAS2500_WEI")
[ -n "$hash" ] || fail_case "send rejected"

status=$(hex2dec "$(receipt_field "$hash" status)")
eff=$(hex2dec "$(receipt_field "$hash" effectiveGasPrice)")
[ "$status" = "1" ] || fail_case "status=$status"
[ "$eff" = "$GAS2500_WEI" ] || fail_case "effectiveGasPrice=$eff != $GAS2500_WEI"
pass_case "sealed at $eff wei"
