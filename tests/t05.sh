#!/bin/bash
# T05 — queue seeding, sender S1: 10 transfers parked in the queue.
source "$(dirname "$0")/gas2500x-lib.sh"
begin_case "T05" "queue seeding, sender S1 (10 queued)" 0.3

require_pre_fork

S1=$(addr_of TXGEN_KEY_1)
S1_TO=$(addr_of TXGEN_KEY_2)
# pending nonce of S1 must be 0; nonces 1..10 create the gap that parks the
# batch in the queue. NOTE: the pool rejects nonces beyond pending+10
# (common.LimitThresholdNonceInQueue), so 10 is the max one account can park.
pending=$(pending_nonce "$S1")
[ "$pending" = "0" ] || fail_case "S1 pending nonce is $pending, expected 0"

# submit nonces 1..10 WITHOUT the missing nonce 0
for n in $(seq 1 10); do
    send_from TXGEN_KEY_1 "$S1_TO" 1 "$GAS50_WEI" "$n" >/dev/null 2>&1 \
        || fail_case "submit nonce $n failed"
done

read -r _ que <<<"$(pool3)"
# pending is read with the genesis signers excluded: their consensus signing
# txs transit the pool as executable-special entries for ~2 s every 30 s
pend=$(pending_regular)
[ "$pend" = "0" ] || fail_case "pending=$pend, expected 0"
[ "$que" = "10" ] || fail_case "queued=$que, expected 10"
pass_case "pending=0 (signers excluded) queued=10"
