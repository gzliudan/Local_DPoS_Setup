#!/bin/bash
# T1 — fund the senders S1/S2/S3 (and confirm P3) from pn0's prefunded signer.
source "$(dirname "$0")/gas2500x-lib.sh"
begin_case "T1" "fund the senders"

head0
# S1..S3 need gas money for T2/T5/T6/T8/T20+: send 1 XDC each from pn0's
# prefunded signer (PRIVATE_KEY_0) at the current suggested price.
for s in TXGEN_KEY_1 TXGEN_KEY_2 TXGEN_KEY_3; do
    to=$(addr_of "$s")
    gp=$(hex2dec "$(rpc0 eth_gasPrice | jq -r .)")
    cast send "$to" --value 1ether --gas-price "$gp"wei --gas-limit 21000 \
        --private-key "$(printenv PRIVATE_KEY_0)" --rpc-url "$RPC0" \
        --chain-id "$CHAIN_ID" --json --legacy >/dev/null 2>&1 || fail_case "fund $s failed"
done

# P3 (pn3's own unlocked keystore account) signs T13's eth_sendTransaction —
# it needs a balance too (10 XDC per the plan).
P3=$(addr_of PRIVATE_KEY_3)
cast send "$P3" --value 10ether --gas-price "$(hex2dec "$(rpc0 eth_gasPrice | jq -r .)")"wei \
    --gas-limit 21000 --private-key "$(printenv PRIVATE_KEY_0)" --rpc-url "$RPC0" \
    --chain-id "$CHAIN_ID" --json --legacy >/dev/null 2>&1 || fail_case "fund P3 failed"

# Every sender must hold a non-zero balance on pn3's view (P3 included).
for s in TXGEN_KEY_1 TXGEN_KEY_2 TXGEN_KEY_3 PRIVATE_KEY_3; do
    to=$(addr_of "$s")
    bal=$(rpc3 eth_getBalance "[\"$to\", \"latest\"]" | jq -r .)
    [ "$(hex2dec "$bal")" -gt 0 ] || fail_case "$s ($to) balance 0"
done
pass_case "S1/S2/S3 funded"
