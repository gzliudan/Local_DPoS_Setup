#!/bin/bash
# T43 — a legacy creation above the tier floor seals on the post-fork tier (625 gwei).
# (The other half of this tx pair is T37.)
source "$(dirname "$0")/gas2500x-lib.sh"
begin_case "T43" "creation above the tier floor seals (legacy, post-fork tier)"

# no guard: the runner schedules this after the fork, past the t29-t31 saga

floor=$GAS2500_WEI
n=$(pending_nonce "$(addr_of TXGEN_KEY_5)")

h=$(create_from TXGEN_KEY_5 legacy "$((floor + 1))" "$CREATION_CODE" "$n" 2>&1) ||
    fail_case "legacy $((floor + 1)) creation rejected: $h"
e=$(receipt_field "$h" effectiveGasPrice 60) || fail_case "never sealed"
[ "$(hex2dec "$e")" = "$((floor + 1))" ] ||
    fail_case "effective=$(hex2dec "$e")"
pass_case "sealed at $((floor + 1)) wei"
