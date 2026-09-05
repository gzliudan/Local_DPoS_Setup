#!/bin/bash
# T19 — a legacy creation above the tier floor seals on the pre-fork tier (12.5 gwei).
# (The other half of this tx pair is T50.)
source "$(dirname "$0")/gas2500x-lib.sh"
begin_case "T19" "creation above the tier floor seals (legacy, pre-fork tier)" 2.0

require_pre_fork "pre side missed the window"

floor=$GAS50_WEI
n=$(pending_nonce "$(addr_of TXGEN_KEY_5)")

h=$(create_from TXGEN_KEY_5 legacy "$((floor + 1))" "$CREATION_CODE" "$n" 2>&1) ||
    fail_case "legacy $((floor + 1)) creation rejected: $h"
e=$(receipt_field "$h" effectiveGasPrice 60) || fail_case "never sealed"
[ "$(hex2dec "$e")" = "$((floor + 1))" ] ||
    fail_case "effective=$(hex2dec "$e")"
pass_case "sealed at $((floor + 1)) wei"
