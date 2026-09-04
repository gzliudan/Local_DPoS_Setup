#!/bin/bash
# T24 — journal load converges on the new-tier replacement (#2541).
source "$(dirname "$0")/gas2500x-lib.sh"
begin_case "T24" "journal load converges on the new-tier replacement"

S2=$(addr_of TXGEN_KEY_2)

./stop-network.sh 3 >/dev/null 2>&1
./run-node.sh 3 >/dev/null 2>&1 || fail_case "pn3 restart failed"
for _ in $(seq 1 30); do
    head=$(head3) && [ -n "$head" ] && break
    sleep 1
done

content=$(rpc3 txpool_contentFrom "[\"$S2\"]")
count=$(printf '%s' "$content" | jq '[.. | .hash? // empty | select(length>0)] | length')
[ "$count" = "1" ] || fail_case "pool holds $count txs at S2, expected 1 (P2)"
price=$(printf '%s' "$content" | jq -r '.. | .gasPrice? // empty' | head -n 1)
[ "$(hex2dec "$price")" = $((GAS2500_WEI * 110 / 100)) ] || \
    fail_case "surviving price $(hex2dec "$price"), expected P2"
pass_case "only P2 (690g) survived the load"
