#!/bin/bash
# T35 — tx1 of the creation matrix: a legacy creation below the tier floor
# is rejected at once (twice-case; floor 12.5 gwei pre-fork, 625 gwei post).
# Usage: t35.sh pre|post
source "$(dirname "$0")/gas2500x-lib.sh"
begin_case "T35" "creation below the tier floor is rejected (legacy, ${1:-?} side)"

side=${1:-pre}
fork_side "$side"

floor=$(tier_for "$side")
n=$(pending_nonce "$(addr_of TXGEN_KEY_5)")

expect_create_reject TXGEN_KEY_5 legacy "$((floor - 1))" "$CREATION_CODE" \
    "under min gas price" "$n" \
    || fail_case "legacy $((floor - 1)) creation was not rejected"
pass_case "rejected: under min gas price (legacy $((floor - 1)) wei)"
