#!/bin/bash
# T34 — no tracker revival within the recheck (#2541): the gauge stays at k
# and the swept txs are not retried into a rejection loop.
source "$(dirname "$0")/gas2500x-lib.sh"
begin_case "T34" "verify no tracker revival within the recheck" 130.0

before=$(journal_size)

# settle: after T33's restart the journal reloads its txs into the POOL at
# the tracker's first recheck — the above-floor P2 returning is CORRECT
# behavior; wait for the pool to stabilize before asserting no revival of
# the BELOW-FLOOR hold-backs
que0=$(pool3 | awk '{print $2}')
sleep 65   # one full recheck period

k=$(gauge3 txpool_local_belowfloor)
sleep 65   # one more recheck under observation

k2=$(gauge3 txpool_local_belowfloor)
read -r _ que <<<"$(pool3)"
pend=$(pending_regular)   # signer-exempt — consensus signing txs transit here
after=$(journal_size)
[ "$k" -gt 0 ] || fail_case "gauge=0, no hold-back observed"
[ "$k2" = "$k" ] || fail_case "gauge moved: $k -> $k2"
if [ "$pend" != "0" ] || [ "$que" != "$que0" ]; then
    fail_case "pools changed: $que0 -> $pend/$que (below-floor revival?)"
fi
[ "$before" = "$after" ] || fail_case "journal grew (resubmit loop)"
pass_case "gauge=k($k), pool stable at $pend/$que, journal stable after rechecks"
