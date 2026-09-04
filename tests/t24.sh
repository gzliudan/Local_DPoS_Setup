#!/bin/bash
# T24 — journal load converges on the new-tier replacement (#2541).
source "$(dirname "$0")/gas2500x-lib.sh"
begin_case "T24" "journal load converges on the new-tier replacement"

S2=$(addr_of TXGEN_KEY_2)

./stop-network.sh 3 >/dev/null 2>&1
pkill -f 'XDC --config nodes/pn3' 2>/dev/null
wait_port_free 8548 20 || true
wait_port_free 6063 5 || true
./run-node.sh 3 >/dev/null 2>&1 || fail_case "pn3 restart failed"
for _ in $(seq 1 30); do
    head=$(head3)
    [ "$head" != "-1" ] && [ -n "$head" ] && break
    sleep 1
done
# journal txs re-enter the pool at the tracker's first recheck (10 s timer)
for _ in $(seq 1 20); do
    content=$(rpc3 txpool_contentFrom "[\"$S2\"]")
    count=$(printf '%s' "$content" | jq '[.. | .hash? // empty | select(length>0)] | length')
    [ "$count" -ge 1 ] && break
    sleep 5
done

content=$(rpc3 txpool_contentFrom "[\"$S2\"]")
count=$(printf '%s' "$content" | jq '[.. | .hash? // empty | select(length>0)] | length')
[ "$count" = "1" ] || fail_case "pool holds $count txs at S2, expected 1 (P2)"
price=$(printf '%s' "$content" | jq -r '.. | .gasPrice? // empty' | head -n 1)
[ "$(hex2dec "$price")" = $((GAS2500_WEI * 552 / 500)) ] || \
    fail_case "surviving price $(hex2dec "$price"), expected P2 (110.4%)"
pass_case "only P2 (110.4%) survived the load"
