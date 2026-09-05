#!/bin/bash
# T21 — an EIP-1559 creation at the tier floor seals on the pre-fork tier (12.5 gwei).
# (The other half of this tx pair is T52.)
source "$(dirname "$0")/gas2500x-lib.sh"
begin_case "T21" "creation at the tier floor seals (1559, pre-fork tier)"

require_pre_fork "pre side missed the window"

floor=$GAS50_WEI
n=$(pending_nonce "$(addr_of TXGEN_KEY_5)")

h=$(create_from TXGEN_KEY_5 maxfee "$floor" "$CREATION_CODE" "$n" 2>&1) ||
    fail_case "1559 fee-cap $floor creation rejected: $h"
e=$(receipt_field "$h" effectiveGasPrice 60) || fail_case "never sealed"
t=$(receipt_field "$h" type 5)
[ "$(hex2dec "$t")" = "2" ] || fail_case "type=$(hex2dec "${t:-?}"), expected 2"
[ "$(hex2dec "$e")" = "$floor" ] || fail_case "effective=$(hex2dec "$e")"
pass_case "sealed at $floor wei (type 2)"
