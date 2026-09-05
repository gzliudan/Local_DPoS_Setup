#!/bin/bash
# T46 — an EIP-1559 creation with tip 0 seals at the base fee on the post-fork tier (625 gwei).
# (The other half of this tx pair is T40.)
source "$(dirname "$0")/gas2500x-lib.sh"
begin_case "T46" "creation with tip 0 seals at the base fee (post-fork tier)"

# no guard: the runner schedules this after the fork, past the t29-t31 saga

floor=$GAS2500_WEI
n=$(pending_nonce "$(addr_of TXGEN_KEY_5)")

h=$(create_from TXGEN_KEY_5 tip 0 "$CREATION_CODE" "$n" 2>&1) ||
    fail_case "tip-0 creation rejected: $h"
e=$(receipt_field "$h" effectiveGasPrice 60) || fail_case "never sealed"
t=$(receipt_field "$h" type 5)
[ "$(hex2dec "$t")" = "2" ] || fail_case "type=$(hex2dec "${t:-?}"), expected 2"
[ "$(hex2dec "$e")" = "$floor" ] ||
    fail_case "effective=$(hex2dec "$e"), expected the base fee ($floor)"
pass_case "sealed at $(hex2dec "$e") wei (tip 0, type 2)"
