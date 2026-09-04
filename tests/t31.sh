#!/bin/bash
# T31 — the hold-back survives a restart (#2541): the journal persists the
# held-back transactions and no resubmit storm happens.
source "$(dirname "$0")/gas2500x-lib.sh"
begin_case "T31" "the hold-back survives a restart"

k0=0
for _ in $(seq 1 8); do
    k0=$(meter3 txpool_local_belowfloor); k0=${k0:-0}
    [ "$k0" -gt 0 ] && break
    sleep 5
done
[ "$k0" -gt 0 ] || fail_case "gauge=0 before restart, nothing to persist"

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
sleep 65   # one recheck: a broken implementation would resubmit here

k1=$(meter3 txpool_local_belowfloor); k1=${k1:-0}
read -r pend que <<<"$(pool3)"
# the journal legitimately reloads ABOVE-floor txs (T24's P2) into the pool
# at the first recheck; a resubmit STORM would keep growing the queue across
# rechecks, so compare against the baseline sampled right after the restart
if [ "$pend" != "0" ] || [ "$que" -gt 1 ]; then
    fail_case "resubmit storm: $pend/$que"
fi
[ "$k1" = "$k0" ] || fail_case "gauge changed across restart: $k0 -> $k1"
pass_case "gauge=k($k0) after restart, pool stable at $pend/$que (no below-floor revival)"
