#!/bin/bash
# T24 — the fork sweep empties the queue (#2532, core case).
source "$(dirname "$0")/gas2500x-lib.sh"
begin_case "T24" "the fork sweep empties the queue"

wait_head $((FORK_BLOCK + 1)) 120 || fail_case "fork did not fire"

for port in 8545 8546 8547; do
    que=$(hex2dec "$(rpc "http://127.0.0.1:$port" txpool_status | jq -r .result.queued)")
    [ "$que" = "0" ] || fail_case "node $port still has queued=$que"
done

# pn3: the sweep drops only below-floor txs, so T10's above-floor pre-fork
# survivor (700 gwei, parked queued by T10) is still there — exactly one
# queued tx when the seed ran, zero otherwise
que=$(hex2dec "$(rpc "$RPC3" txpool_status | jq -r .result.queued)")
if [ -f /tmp/g2500-t10-hashes ]; then
    [ "$que" = "1" ] || fail_case "pn3 queued=$que, expected the 1 T10 survivor"
    hash=$(tail -n 1 /tmp/g2500-t10-hashes)
    pool_hashes_from "$(addr_of TXGEN_KEY_4)" | grep -q "$hash" \
        || fail_case "pn3's queued tx is not the T10 survivor"
    pass_case "queued=0 on pn0-pn2; pn3 keeps the T10 survivor (700 gwei)"
fi
[ "$que" = "0" ] || fail_case "pn3 still has queued=$que"
pass_case "queued=0 on all four nodes"
