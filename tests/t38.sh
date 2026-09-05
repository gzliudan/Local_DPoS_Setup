#!/bin/bash
# T38 — tx4 of the creation matrix: an EIP-1559 creation whose fee cap is
# below the tier floor is rejected at once — the floor compares a dynamic
# tx's GasFeeCap (twice-case). Usage: t38.sh pre|post
source "$(dirname "$0")/gas2500x-lib.sh"
begin_case "T38" "creation below the tier floor is rejected (1559, ${1:-?} side)"

side=${1:-pre}
fork_side "$side"

floor=$(tier_for "$side")
n=$(pending_nonce "$(addr_of TXGEN_KEY_5)")

expect_create_reject TXGEN_KEY_5 maxfee "$((floor - 1))" "$CREATION_CODE" \
    "under min gas price" "$n" \
    || fail_case "1559 fee-cap $((floor - 1)) creation was not rejected"
pass_case "rejected: under min gas price (fee cap $((floor - 1)) wei)"
