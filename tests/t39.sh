#!/bin/bash
# T39 — tx5 of the creation matrix: an EIP-1559 creation whose fee cap is
# exactly the tier floor is admitted and seals at the floor (twice-case).
# Usage: t39.sh pre|post
source "$(dirname "$0")/gas2500x-lib.sh"
begin_case "T39" "creation at the tier floor seals (1559, ${1:-?} side)"

side=${1:-pre}
fork_side "$side"

floor=$(tier_for "$side")
n=$(pending_nonce "$(addr_of TXGEN_KEY_5)")

h=$(create_from TXGEN_KEY_5 maxfee "$floor" "$CREATION_CODE" "$n" 2>&1) ||
    fail_case "1559 fee-cap $floor creation rejected: $h"
e=$(receipt_field "$h" effectiveGasPrice 60) || fail_case "never sealed"
t=$(receipt_field "$h" type 5)
[ "$(hex2dec "$t")" = "2" ] || fail_case "type=$(hex2dec "${t:-?}"), expected 2"
[ "$(hex2dec "$e")" = "$floor" ] || fail_case "effective=$(hex2dec "$e")"
pass_case "sealed at $floor wei (type 2)"
