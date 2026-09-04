#!/bin/bash
# T5 — queue seeding, sender S1: 60 transfers parked in the queue.
source "$(dirname "$0")/gas2500x-lib.sh"
begin_case "T5" "queue seeding, sender S1 (60 queued)"

head=$(head3)
[ "$head" -lt "$FORK_BLOCK" ] || skip_case "head $head >= fork $FORK_BLOCK; run before the fork"

S1=$(addr_of TXGEN_KEY_1)
S1_TO=$(addr_of TXGEN_KEY_2)
# pending nonce of S1 must be 0; nonces 1..10 create the gap that parks the
# batch in the queue. NOTE: the pool rejects nonces beyond pending+10
# (common.LimitThresholdNonceInQueue), so 10 is the max one account can park.
pending=$(hex2dec "$(rpc3 eth_getTransactionCount "[\"$S1\", \"pending\"]" | jq -r .)")
[ "$pending" = "0" ] || fail_case "S1 pending nonce is $pending, expected 0"

# submit nonces 1..10 WITHOUT the missing nonce 0
for n in $(seq 1 10); do
    send_from TXGEN_KEY_1 "$S1_TO" 1 "$GAS50_WEI" "$n" >/dev/null 2>&1 \
        || fail_case "submit nonce $n failed"
done

read -r pend que <<<"$(pool3)"
[ "$pend" = "0" ] || fail_case "pending=$pend, expected 0"
[ "$que" = "10" ] || fail_case "queued=$que, expected 10"
pass_case "pending=0 queued=10"
