#!/bin/bash
# T20 — an EIP-1559 creation below the tier floor is rejected on the pre-fork tier (12.5 gwei).
# (The other half of this tx pair is T51.)
source "$(dirname "$0")/gas2500x-lib.sh"
begin_case "T20" "creation below the tier floor is rejected (1559, pre-fork tier)" 0.0

require_pre_fork "pre side missed the window"

floor=$GAS50_WEI
n=$(pending_nonce "$(addr_of TXGEN_KEY_5)")

expect_create_reject TXGEN_KEY_5 maxfee "$((floor - 1))" "$CREATION_CODE" \
    "under min gas price" "$n" \
    || fail_case "1559 fee-cap $((floor - 1)) creation was not rejected"
pass_case "rejected: under min gas price (fee cap $((floor - 1)) wei)"
