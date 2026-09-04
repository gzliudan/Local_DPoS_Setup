#!/bin/bash
# T6 — queue seeding, sender S2: 10 transfers parked in the queue.
source "$(dirname "$0")/gas2500x-lib.sh"
begin_case "T6" "queue seeding, sender S2 (10 queued)"

head=$(head3)
[ "$head" -lt "$FORK_BLOCK" ] || skip_case "head $head >= fork $FORK_BLOCK; run before the fork"

S2=$(addr_of TXGEN_KEY_2)
S2_TO=$(addr_of TXGEN_KEY_1)
pending=$(hex2dec "$(rpc3 eth_getTransactionCount "[\"$S2\", \"pending\"]" | jq -r .)")
[ "$pending" = "0" ] || fail_case "S2 pending nonce is $pending, expected 0"

for n in $(seq 3 12); do
    send_from TXGEN_KEY_2 "$S2_TO" 1 "$GAS50_WEI" "$n" >/dev/null 2>&1 \
        || fail_case "submit nonce $n failed"
done

read -r pend que <<<"$(pool3)"
[ "$pend" = "0" ] || fail_case "pending=$pend"
[ "$que" = "70" ] || fail_case "queued=$que, expected 70"
pass_case "pending=0 queued=70"
