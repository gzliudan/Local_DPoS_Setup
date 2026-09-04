#!/bin/bash
# T3 — below-floor rejection on the pre-fork tier: 12.5 gwei − 1 wei.
source "$(dirname "$0")/gas2500x-lib.sh"
begin_case "T3" "below-floor rejection on the pre-fork tier (12.5 gwei − 1)"

head=$(head3)
[ "$head" -lt "$FORK_BLOCK" ] || skip_case "head $head >= fork $FORK_BLOCK; run before the fork"

S1_TO=$(addr_of TXGEN_KEY_1)
expect_reject TXGEN_KEY_3 "$S1_TO" 1000000000000 $((GAS50_WEI - 1)) \
    "under min gas price" || fail_case "not rejected with under min gas price"
pass_case "rejected: under min gas price"
