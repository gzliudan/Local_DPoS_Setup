#!/bin/bash
# T09 — journal load converges on the replacement (pre-fork, #2541):
# after a restart the pool holds only P2 at nonce 10.
source "$(dirname "$0")/gas2500x-lib.sh"
begin_case "T09" "journal load converges on the replacement (pre-fork)"

S2=$(addr_of TXGEN_KEY_2)

restart_pn3 || fail_case "pn3 restart failed"

# the journal load only re-populates the tracker's in-memory table; the txs
# re-enter the POOL at the tracker's first recheck (timer: 10 s after start)
for _ in $(seq 1 20); do
    [ "$(pool_txs_from "$S2")" -ge 9 ] && break
    sleep 5
done

# after the load: S2 holds T06's 2..9 (8 txs) plus P2 at nonce 10 — and P1
# (the superseded tx) must be gone
count=$(pool_txs_from "$S2")
[ "$count" = "9" ] || fail_case "pool holds $count txs at S2, expected 9 (2..9 + P2)"
content=$(content_from "$S2")
n10=$(printf '%s' "$content" | jq '[.. | objects | select(.nonce? == "0xa")] | length')
[ "$n10" = "1" ] || fail_case "nonce 10 slot holds $n10 txs, expected 1 (P2)"
p1h=$(head -n 1 /tmp/g2500-t8-hashes 2>/dev/null)
if [ -n "$p1h" ] && printf '%s' "$content" | grep -qi "$p1h"; then
    fail_case "superseded P1 ($p1h) still in the pool after the load"
fi
pass_case "journal load keeps only P2 at nonce 10 (9 S2 txs total)"
