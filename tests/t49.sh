#!/bin/bash
# T49 — a legacy creation at the tier floor seals on the post-fork tier (625 gwei).
# (The other half of this tx pair is T16.)
source "$(dirname "$0")/gas2500x-lib.sh"
begin_case "T49" "seal a legacy creation at the tier floor (post-fork tier)" 2.0

# no guard: the runner schedules this after the fork, past the t43 … t45 saga

floor=$GAS2500_WEI
n=$(pending_nonce "$(addr_of TXGEN_KEY_5)")

h=$(create_from TXGEN_KEY_5 legacy "$floor" "$CREATION_CODE" "$n" 2>&1) ||
    fail_case "legacy $floor creation rejected: $h"
e=$(receipt_field "$h" effectiveGasPrice 60) || fail_case "never sealed"
[ "$(hex2dec "$e")" = "$floor" ] || fail_case "effective=$(hex2dec "$e")"
pass_case "sealed at $floor wei"
