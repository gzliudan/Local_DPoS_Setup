#!/bin/bash
# T1 — fund the senders S1/S2/S3 (and confirm P3) from pn0's prefunded signer.
source "$(dirname "$0")/gas2500x-lib.sh"
begin_case "T01" "fund the senders"

# Funding list: S1..S3 need gas money for T2/T5/T6/T8/T20+ (1 XDC each) and
# P3 (pn3's own unlocked keystore account, signs T13's send) needs 10 XDC.
# Sent from pn0's prefunded signer (PRIVATE_KEY_0) at the current suggested
# price; the sends stay synchronous (no --async) so the funds are confirmed
# before the pool cases start.
gp=$(hex2dec "$(rpc0 eth_gasPrice | jq -r .)")
for spec in "TXGEN_KEY_1 1ether" "TXGEN_KEY_2 1ether" \
    "TXGEN_KEY_3 1ether" "PRIVATE_KEY_3 10ether"; do
    read -r s value <<<"$spec"
    cast send "$(addr_of "$s")" --value "$value" --gas-price "$gp"wei \
        --gas-limit 21000 --private-key "$(printenv PRIVATE_KEY_0)" \
        --rpc-url "$RPC0" --chain-id "$CHAIN_ID" --json --legacy \
        >/dev/null 2>&1 || fail_case "fund $s failed"
done

# Every sender must hold a non-zero balance on pn3's view (P3 included).
for s in TXGEN_KEY_1 TXGEN_KEY_2 TXGEN_KEY_3 PRIVATE_KEY_3; do
    to=$(addr_of "$s")
    bal=$(rpc3 eth_getBalance "[\"$to\", \"latest\"]" | jq -r .)
    [ "$(hex2dec "$bal")" -gt 0 ] || fail_case "$s ($to) balance 0"
done
pass_case "S1/S2/S3 funded"
