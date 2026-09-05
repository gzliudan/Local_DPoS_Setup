#!/bin/bash
# T37 — tx3 of the creation matrix: a legacy creation one wei above the tier
# floor is admitted and seals at its own price (twice-case; 12.5 gwei + 1
# pre-fork, 625 gwei + 1 post). Usage: t37.sh pre|post
source "$(dirname "$0")/gas2500x-lib.sh"
begin_case "T37" "creation above the tier floor seals (legacy, ${1:-?} side)"

side=${1:-pre}
fork_side "$side"

floor=$(tier_for "$side")
n=$(pending_nonce "$(addr_of TXGEN_KEY_5)")

h=$(create_from TXGEN_KEY_5 legacy "$((floor + 1))" "$CREATION_CODE" "$n" 2>&1) ||
    fail_case "legacy $((floor + 1)) creation rejected: $h"
e=$(receipt_field "$h" effectiveGasPrice 60) || fail_case "never sealed"
[ "$(hex2dec "$e")" = "$((floor + 1))" ] ||
    fail_case "effective=$(hex2dec "$e")"
pass_case "sealed at $((floor + 1)) wei"
