#!/bin/bash
# T44 — an EIP-1559 creation below the tier floor is rejected on the post-fork tier (625 gwei).
# (The other half of this tx pair is T38.)
source "$(dirname "$0")/gas2500x-lib.sh"
begin_case "T44" "creation below the tier floor is rejected (1559, post-fork tier)"

# no guard: the runner schedules this after the fork, past the t29-t31 saga

floor=$GAS2500_WEI
n=$(pending_nonce "$(addr_of TXGEN_KEY_5)")

expect_create_reject TXGEN_KEY_5 maxfee "$((floor - 1))" "$CREATION_CODE" \
    "under min gas price" "$n" \
    || fail_case "1559 fee-cap $((floor - 1)) creation was not rejected"
pass_case "rejected: under min gas price (fee cap $((floor - 1)) wei)"
