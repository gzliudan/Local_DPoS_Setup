#!/bin/bash
# T19 — an EIP-1559 creation with tip 0 seals at the base fee on the pre-fork tier (12.5 gwei).
# (The other half of this tx pair is T52.)
source "$(dirname "$0")/gas2500x-lib.sh"
begin_case "T19" "seal a tip-0 creation at the pre-fork base fee" 2.1

require_pre_fork "pre-fork window missed"

floor=$GAS50_WEI
n=$(pending_nonce "$(addr_of TXGEN_KEY_5)")

h=$(create_from TXGEN_KEY_5 tip 0 "$CREATION_CODE" "$n" 2>&1) ||
    fail_case "tip-0 creation rejected: $h"
e=$(receipt_field "$h" effectiveGasPrice 60) || fail_case "never sealed"
t=$(receipt_field "$h" type 5)
[ "$(hex2dec "$t")" = "2" ] || fail_case "type=$(hex2dec "${t:-?}"), expected 2"
[ "$(hex2dec "$e")" = "$floor" ] ||
    fail_case "effective=$(hex2dec "$e"), expected the base fee ($floor)"
pass_case "sealed at $(hex2dec "$e") wei (tip 0, type 2)"
