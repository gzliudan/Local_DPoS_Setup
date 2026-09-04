#!/bin/bash
# T17 — the fork sweep empties the queue (#2532, core case).
source "$(dirname "$0")/gas2500x-lib.sh"
begin_case "T17" "the fork sweep empties the queue"

wait_head $((FORK_BLOCK + 1)) 120 || fail_case "fork did not fire"

for port in 8545 8546 8547 8548; do
    r=$(curl -s "http://127.0.0.1:$port" -X POST -H 'Content-Type: application/json' \
        --data '{"jsonrpc":"2.0","id":1,"method":"txpool_status","params":[]}')
    que=$(hex2dec "$(printf '%s' "$r" | jq -r .result.queued)")
    [ "$que" = "0" ] || fail_case "node $port still has queued=$que"
done
pass_case "queued=0 on all four nodes"
