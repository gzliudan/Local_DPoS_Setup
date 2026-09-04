#!/bin/bash
# T6 — queue seeding, sender S2: 8 transfers parked in the queue.
source "$(dirname "$0")/gas2500x-lib.sh"
begin_case "T06" "queue seeding, sender S2 (10 queued)"

require_pre_fork

S2=$(addr_of TXGEN_KEY_2)
S2_TO=$(addr_of TXGEN_KEY_1)
pending=$(pending_nonce "$S2")
[ "$pending" = "0" ] || fail_case "S2 pending nonce is $pending, expected 0"

# nonces 2..9 (8 txs, gap at 0..1; nonce 10 stays free for T8's replacement
# pair and the pending+10 cap caps us at nonce 10 anyway)
for n in $(seq 2 9); do
    send_from TXGEN_KEY_2 "$S2_TO" 1 "$GAS50_WEI" "$n" >/dev/null 2>&1 \
        || fail_case "submit nonce $n failed"
done

read -r pend que <<<"$(pool3)"
[ "$pend" = "0" ] || fail_case "pending=$pend"
[ "$que" = "18" ] || fail_case "queued=$que, expected 18"
pass_case "pending=0 queued=18"
