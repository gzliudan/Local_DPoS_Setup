#!/bin/bash
# T29 — below-floor rejection on the new tier: 624999999999 wei.
source "$(dirname "$0")/gas2500x-lib.sh"
begin_case "T29" "below-floor rejection on the new tier (624999999999 wei)" 0.0

S1_TO=$(addr_of TXGEN_KEY_2)
expect_reject TXGEN_KEY_1 "$S1_TO" 1 $((GAS2500_WEI - 1)) \
    "under min gas price" || fail_case "not rejected with under min gas price"
pass_case "rejected: under min gas price"
