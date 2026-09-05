#!/bin/bash
# T53 — EIP-1559 admission at the new floor (#2516): the pool floor compares
# a dynamic-fee tx's fee CAP (DynamicFeeTx.gasPrice is the fee cap), so a
# type-2 tx with fee cap = 625 gwei is admitted exactly where the legacy tx
# of T29 is, and it seals at the floor: effectiveGasPrice =
# min(feeCap, baseFee + tip) = 625 gwei.
source "$(dirname "$0")/gas2500x-lib.sh"
begin_case "T53" "seal a 1559 tx at the new floor (fee cap = 625 gwei)" 2.1

require_post_fork

S1_ADDR=$(addr_of TXGEN_KEY_1)
S1_TO=$(addr_of TXGEN_KEY_2)
nonce=$(pending_nonce "$S1_ADDR")
# cast 1.8: on a non-legacy send --gas-price IS the max fee per gas
hash=$(send_from TXGEN_KEY_1 "$S1_TO" 1 "$GAS2500_WEI" "$nonce" \
    --priority-gas-price 1000000000wei)
[ -n "$hash" ] || fail_case "send rejected"

status=$(hex2dec "$(receipt_field "$hash" status)")
eff=$(hex2dec "$(receipt_field "$hash" effectiveGasPrice)")
txtype=$(receipt_field "$hash" type)
[ "$status" = "1" ] || fail_case "status=$status"
[ "$txtype" = "0x2" ] || fail_case "type=$txtype, expected a 0x2 dynamic-fee tx"
[ "$eff" = "$GAS2500_WEI" ] || fail_case "effectiveGasPrice=$eff != $GAS2500_WEI"
pass_case "type-2 tx sealed at $eff wei"
