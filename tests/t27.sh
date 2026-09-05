#!/bin/bash
# T27 — the sweep leaves a hold-back gauge (#2541): pn3=k, masternodes 0.
source "$(dirname "$0")/gas2500x-lib.sh"
begin_case "T27" "the sweep leaves a hold-back gauge" 0.0

# the hold-back materializes at the tracker's next recheck (10 s/60 s cadence)
k=0
for _ in $(seq 1 15); do
    k=$(gauge3 txpool_local_belowfloor)
    [ "$k" -gt 0 ] && break
    sleep 5
done
[ "$k" -gt 0 ] || fail_case "gauge=0 after 75 s, expected the held-back count"
for port in 6060 6061 6062; do
    v=$(meter_port "$port" txpool_local_belowfloor)
    [ "${v:-0}" = "0" ] || fail_case "masternode :$port gauge=$v, expected 0"
done
pass_case "pn3 gauge=k($k), masternodes 0"
