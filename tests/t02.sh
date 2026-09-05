#!/bin/bash
# T02 — below-floor rejection on the pre-fork tier: 12499999999 wei.
source "$(dirname "$0")/gas2500x-lib.sh"
begin_case "T02" "below-floor rejection on the pre-fork tier (12499999999 wei)" 0.0

require_pre_fork

S1_TO=$(addr_of TXGEN_KEY_1)
expect_reject TXGEN_KEY_3 "$S1_TO" 1000000000000 $((GAS50_WEI - 1)) \
    "under min gas price" || fail_case "not rejected with under min gas price"
pass_case "rejected: under min gas price"
