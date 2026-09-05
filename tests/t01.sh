#!/bin/bash
# T01 — fund the senders S1-S5 (and confirm P3) from pn0's prefunded signer.
source "$(dirname "$0")/gas2500x-lib.sh"
begin_case "T01" "fund the senders" 1.4

# Funding list: S1..S3 need gas money for T09/T11/T12/T13/T29+ and S4 for T21's
# above-floor survivor (1 XDC each); S5 (T07's creation-pricing probes) gets
# 2 XDC (four ~53k-gas creates per side); P3 (pn3's own account, sender of
# T15's default-price tx) needs 10 XDC.
# All six transfers are submitted ASYNC with explicit sequential nonces, so
# the whole batch rides ONE block (~2 s) instead of six serial receipt waits
# (~2 s each — the old 10.8 s T01). The receipts are then confirmed
# (status=1) before the pool cases start.
gp=$(hex2dec "$(rpc0 eth_gasPrice | jq -r .)")
from=$(addr_of PRIVATE_KEY_0)
n0=$(hex2dec "$(rpc0 eth_getTransactionCount "[\"$from\", \"pending\"]" | jq -r .)")

hashes=()
i=0
for spec in "TXGEN_KEY_1 1ether" "TXGEN_KEY_2 1ether" \
    "TXGEN_KEY_3 1ether" "TXGEN_KEY_4 1ether" "TXGEN_KEY_5 2ether" \
    "PRIVATE_KEY_3 10ether"; do
    read -r s value <<<"$spec"
    out=$(cast send "$(addr_of "$s")" --value "$value" --gas-price "$gp"wei \
        --gas-limit 21000 --nonce $((n0 + i)) \
        --private-key "$(printenv PRIVATE_KEY_0)" \
        --rpc-url "$RPC0" --chain-id "$CHAIN_ID" --json --legacy --async 2>&1)
    case $out in
    0x[0-9a-fA-F]*) hashes+=("$out") ;;
    *) fail_case "fund $s failed: $out" ;;
    esac
    i=$((i + 1))
done

# every receipt must exist and report success (receipt_field polls pn3)
for h in "${hashes[@]}"; do
    st=$(receipt_field "$h" status 60) || fail_case "fund receipt $h never arrived"
    [ "$(hex2dec "$st")" = "1" ] || fail_case "fund tx $h status=$(hex2dec "$st")"
done

# Every sender must hold a non-zero balance on pn3's view (P3 included).
for s in TXGEN_KEY_1 TXGEN_KEY_2 TXGEN_KEY_3 TXGEN_KEY_4 TXGEN_KEY_5 \
    PRIVATE_KEY_3; do
    to=$(addr_of "$s")
    bal=$(rpc3 eth_getBalance "[\"$to\", \"latest\"]" | jq -r .)
    [ "$(hex2dec "$bal")" -gt 0 ] || fail_case "$s ($to) balance 0"
done
pass_case "S1/S2/S3/S4/S5 funded"
