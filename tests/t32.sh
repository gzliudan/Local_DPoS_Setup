#!/bin/bash
# T32 — journal load converges on the new-tier replacement (#2541).
source "$(dirname "$0")/gas2500x-lib.sh"
begin_case "T32" "journal load converges on the new-tier replacement" 12.1

S2=$(addr_of TXGEN_KEY_2)

restart_pn3 || fail_case "pn3 restart failed"

# journal txs re-enter the pool at the tracker's first recheck (10 s timer)
for _ in $(seq 1 20); do
    [ "$(pool_txs_from "$S2")" -ge 1 ] && break
    sleep 5
done

count=$(pool_txs_from "$S2")
[ "$count" = "1" ] || fail_case "pool holds $count txs at S2, expected 1 (P2)"
content=$(content_from "$S2")
price=$(printf '%s' "$content" | jq -r '.. | .gasPrice? // empty' | head -n 1)
[ "$(hex2dec "$price")" = $((GAS2500_WEI * 552 / 500)) ] || \
    fail_case "surviving price $(hex2dec "$price"), expected P2 (110.4%)"
pass_case "only P2 (110.4%) survived the load"
