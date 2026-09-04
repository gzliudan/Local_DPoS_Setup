#!/bin/bash
# T25 — a swept transaction cannot re-enter at the old price (#2532/#2541).
source "$(dirname "$0")/gas2500x-lib.sh"
begin_case "T25" "a swept transaction cannot re-enter at the old price"

require_post_fork

S1_TO=$(addr_of TXGEN_KEY_2)
expect_reject TXGEN_KEY_1 "$S1_TO" 1 "$GAS50_WEI" \
    "under min gas price" || fail_case "old-price tx was not rejected"
pass_case "12.5g tx rejected post-fork"
