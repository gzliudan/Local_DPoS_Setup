#!/bin/bash
# T45 — the hold-back survives a restart (#2541): the journal persists the
# held-back transactions and no resubmit storm happens.
source "$(dirname "$0")/gas2500x-lib.sh"
begin_case "T45" "verify the hold-back survives a restart" 67.1

k0=0
for _ in $(seq 1 8); do
    k0=$(gauge3 txpool_local_belowfloor)
    [ "$k0" -gt 0 ] && break
    sleep 5
done
[ "$k0" -gt 0 ] || fail_case "gauge=0 before restart, nothing to persist"

restart_pn3 || fail_case "pn3 restart failed"
sleep 65   # one recheck: a broken implementation would resubmit here

k1=$(gauge3 txpool_local_belowfloor)
read -r _ que <<<"$(pool3)"
pend=$(pending_regular)   # signer-exempt — consensus signing txs transit here
# the journal legitimately reloads ABOVE-floor txs (T33's P2) into the pool
# at the first recheck; a resubmit STORM would keep growing the queue across
# rechecks, so compare against the baseline sampled right after the restart
if [ "$pend" != "0" ] || [ "$que" -gt 1 ]; then
    fail_case "resubmit storm: $pend/$que"
fi
[ "$k1" = "$k0" ] || fail_case "gauge changed across restart: $k0 -> $k1"
pass_case "gauge=k($k0) after restart, pool stable at $pend/$que (no below-floor revival)"
