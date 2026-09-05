#!/bin/bash
# T36 — tx2 of the creation matrix: a legacy creation exactly at the tier
# floor is admitted and seals at the floor (twice-case; 12.5 gwei pre-fork,
# 625 gwei post). Usage: t36.sh pre|post
source "$(dirname "$0")/gas2500x-lib.sh"
begin_case "T36" "creation at the tier floor seals (legacy, ${1:-?} side)"

side=${1:-pre}
fork_side "$side"

floor=$(tier_for "$side")
n=$(pending_nonce "$(addr_of TXGEN_KEY_5)")

h=$(create_from TXGEN_KEY_5 legacy "$floor" "$CREATION_CODE" "$n" 2>&1) ||
    fail_case "legacy $floor creation rejected: $h"
e=$(receipt_field "$h" effectiveGasPrice 60) || fail_case "never sealed"
[ "$(hex2dec "$e")" = "$floor" ] || fail_case "effective=$(hex2dec "$e")"
pass_case "sealed at $floor wei"
