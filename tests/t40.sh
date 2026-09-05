#!/bin/bash
# T40 — tx6 of the creation matrix: an EIP-1559 creation with a zero tip is
# admitted (the floor compares the fee cap, which cast estimates) and seals
# at the base fee (twice-case). Usage: t40.sh pre|post
source "$(dirname "$0")/gas2500x-lib.sh"
begin_case "T40" "creation with tip 0 seals at the base fee (${1:-?} side)"

side=${1:-pre}
fork_side "$side"

floor=$(tier_for "$side")
n=$(pending_nonce "$(addr_of TXGEN_KEY_5)")

h=$(create_from TXGEN_KEY_5 tip 0 "$CREATION_CODE" "$n" 2>&1) ||
    fail_case "tip-0 creation rejected: $h"
e=$(receipt_field "$h" effectiveGasPrice 60) || fail_case "never sealed"
t=$(receipt_field "$h" type 5)
[ "$(hex2dec "$t")" = "2" ] || fail_case "type=$(hex2dec "${t:-?}"), expected 2"
[ "$(hex2dec "$e")" = "$floor" ] ||
    fail_case "effective=$(hex2dec "$e"), expected the base fee ($floor)"
pass_case "sealed at $(hex2dec "$e") wei (tip 0, type 2)"
