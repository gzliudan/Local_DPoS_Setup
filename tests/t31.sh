#!/bin/bash
# T31 — the hold-back survives a restart (#2541): the journal persists the
# held-back transactions and no resubmit storm happens.
source "$(dirname "$0")/gas2500x-lib.sh"
begin_case "T31" "the hold-back survives a restart"

k0=$(meter3 txpool_local_belowfloor); k0=${k0:-0}
[ "$k0" -gt 0 ] || fail_case "gauge=0 before restart, nothing to persist"

./stop-network.sh 3 >/dev/null 2>&1
./run-node.sh 3 >/dev/null 2>&1 || fail_case "pn3 restart failed"
for _ in $(seq 1 30); do
    head=$(head3) && [ -n "$head" ] && break
    sleep 1
done
sleep 65   # one recheck: a broken implementation would resubmit here

k1=$(meter3 txpool_local_belowfloor); k1=${k1:-0}
read -r pend que <<<"$(pool3)"
[ "$k1" = "$k0" ] || fail_case "gauge changed across restart: $k0 -> $k1"
if [ "$pend" != "0" ] || [ "$que" != "0" ]; then
    fail_case "resubmit storm: $pend/$que"
fi
pass_case "gauge=k($k0) after restart, no resubmit storm"
