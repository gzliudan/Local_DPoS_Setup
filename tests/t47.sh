#!/bin/bash
# T47 — a legacy creation below the tier floor is rejected on the post-fork tier (625 gwei).
# (The other half of this tx pair is T07.)
source "$(dirname "$0")/gas2500x-lib.sh"
begin_case "T47" "reject a legacy creation below the post-fork floor" 0.0

# no guard: the runner schedules this after the fork, past the t43 … t45 saga

floor=$GAS2500_WEI
n=$(pending_nonce "$(addr_of TXGEN_KEY_5)")

expect_create_reject TXGEN_KEY_5 legacy "$((floor - 1))" "$CREATION_CODE" \
    "under min gas price" "$n" \
    || fail_case "legacy $((floor - 1)) creation was not rejected"
pass_case "rejected: under min gas price (legacy $((floor - 1)) wei)"
