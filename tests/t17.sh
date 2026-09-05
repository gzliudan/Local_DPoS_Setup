#!/bin/bash
# T17 — a legacy creation below the tier floor is rejected on the pre-fork tier (12.5 gwei).
# (The other half of this tx pair is T48.)
source "$(dirname "$0")/gas2500x-lib.sh"
begin_case "T17" "creation below the tier floor is rejected (legacy, pre-fork tier)"

require_pre_fork "pre side missed the window"

floor=$GAS50_WEI
n=$(pending_nonce "$(addr_of TXGEN_KEY_5)")

expect_create_reject TXGEN_KEY_5 legacy "$((floor - 1))" "$CREATION_CODE" \
    "under min gas price" "$n" \
    || fail_case "legacy $((floor - 1)) creation was not rejected"
pass_case "rejected: under min gas price (legacy $((floor - 1)) wei)"
