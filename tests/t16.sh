#!/bin/bash
# T16 — a legacy creation at the tier floor seals on the pre-fork tier (12.5 gwei).
# (The other half of this tx pair is T49.)
source "$(dirname "$0")/gas2500x-lib.sh"
begin_case "T16" "seal a legacy creation at the pre-fork floor" 2.1

require_pre_fork "pre-fork window missed"

floor=$GAS50_WEI
n=$(pending_nonce "$(addr_of TXGEN_KEY_5)")

h=$(create_from TXGEN_KEY_5 legacy "$floor" "$CREATION_CODE" "$n" 2>&1) ||
    fail_case "legacy $floor creation rejected: $h"
e=$(receipt_field "$h" effectiveGasPrice 60) || fail_case "never sealed"
[ "$(hex2dec "$e")" = "$floor" ] || fail_case "effective=$(hex2dec "$e")"
pass_case "sealed at $floor wei"
