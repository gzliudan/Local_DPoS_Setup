#!/bin/bash
# T46 — EIP-1559 rejection below the new floor (#2516): a type-2 tx whose fee
# cap is 1 wei under 625 gwei hits the same admission floor as a legacy tx
# (T27 is the legacy mirror) and is rejected with "under min gas price".
source "$(dirname "$0")/gas2500x-lib.sh"
begin_case "T46" "reject a 1559 tx 1 wei below the post-fork floor" 0.0

require_post_fork

S1_ADDR=$(addr_of TXGEN_KEY_1)
S1_TO=$(addr_of TXGEN_KEY_2)
nonce=$(pending_nonce "$S1_ADDR")
# cast 1.8: on a non-legacy send --gas-price IS the max fee per gas
expect_reject TXGEN_KEY_1 "$S1_TO" 1 "$((GAS2500_WEI - 1))" \
    "under min gas price" "$nonce" --priority-gas-price 1000000000wei \
    || fail_case "type-2 tx with fee cap $((GAS2500_WEI - 1)) was admitted"
pass_case "rejected: under min gas price (fee cap $((GAS2500_WEI - 1)) wei)"
