#!/bin/bash
# T48 — an EIP-1559 creation below the tier floor is rejected on the post-fork tier (625 gwei).
# (The other half of this tx pair is T08.)
source "$(dirname "$0")/gas2500x-lib.sh"
begin_case "T48" "reject a 1559 creation below the post-fork floor" 0.0

# no guard: the runner schedules this after the fork, past the t43 … t45 saga

floor=$GAS2500_WEI
n=$(pending_nonce "$(addr_of TXGEN_KEY_5)")

expect_create_reject TXGEN_KEY_5 maxfee "$((floor - 1))" "$CREATION_CODE" \
    "under min gas price" "$n" \
    || fail_case "1559 fee-cap $((floor - 1)) creation was not rejected"
pass_case "rejected: under min gas price (fee cap $((floor - 1)) wei)"
