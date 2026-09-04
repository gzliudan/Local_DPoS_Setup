#!/bin/bash
# T26 — no tracker revival within the recheck (#2541): the gauge stays at k
# and the swept txs are not retried into a rejection loop.
source "$(dirname "$0")/gas2500x-lib.sh"
begin_case "T26" "no tracker revival within the recheck"

before=$(journal_size)
k=$(meter3 txpool_local_belowfloor); k=${k:-0}
sleep 65   # one full recheck period

k2=$(meter3 txpool_local_belowfloor); k2=${k2:-0}
read -r pend que <<<"$(pool3)"
after=$(journal_size)
[ "$k2" = "$k" ] || fail_case "gauge moved: $k -> $k2"
if [ "$pend" != "0" ] || [ "$que" != "0" ]; then
    fail_case "pools re-populated: $pend/$que"
fi
[ "$before" = "$after" ] || fail_case "journal grew (resubmit loop)"
pass_case "gauge=k($k), pools empty, journal stable after one recheck"
