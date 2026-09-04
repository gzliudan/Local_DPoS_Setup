#!/bin/bash
# T9 — journal load converges on the replacement (pre-fork, #2541):
# after a restart the pool holds only P2 at nonce 20.
source "$(dirname "$0")/gas2500x-lib.sh"
begin_case "T9" "journal load converges on the replacement (pre-fork)"

S2=$(addr_of TXGEN_KEY_2)

./stop-network.sh 3 >/dev/null 2>&1
./run-node.sh 3 >/dev/null 2>&1 || fail_case "pn3 restart failed"

# wait for the pn3 RPC to come back
for _ in $(seq 1 30); do
    head=$(head3) && [ -n "$head" ] && break
    sleep 1
done

# after the load: nonce 20 slot holds only the dearer P2 (14 gwei)
content=$(rpc3 txpool_contentFrom "[\"$S2\"]")
count=$(printf '%s' "$content" | jq '[.. | .hash? // empty | select(length>0)] | length')
[ "$count" = "1" ] || fail_case "pool holds $count txs at S2, expected 1 (P2)"
price=$(printf '%s' "$content" | jq -r '.. | .gasPrice? // empty' | head -n 1)
[ "$(hex2dec "$price")" = $((GAS50_WEI * 112 / 100)) ] || \
    fail_case "surviving tx price $(hex2dec "$price"), expected P2 ($((GAS50_WEI * 112 / 100)))"
pass_case "journal load keeps only P2"
