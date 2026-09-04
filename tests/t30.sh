#!/bin/bash
# T30 — the re-cross sweep fires again (#2532): after T29's resync crosses
# block 90 the revived txs are swept a second time.
source "$(dirname "$0")/gas2500x-lib.sh"
begin_case "T30" "the re-cross sweep fires again"

k=$(meter3 txpool_local_belowfloor); k=${k:-0}
[ "$k" -gt 0 ] || fail_case "gauge=0 after resync, expected k again"
m=$(meter3 txpool_belowfloor); m=${m:-0}
[ "$m" -ge $((k * 2)) ] || fail_case "meter=$m, expected >= 2×k (swept twice)"
read -r pend que <<<"$(pool3)"
if [ "$pend" != "0" ] || [ "$que" != "0" ]; then
    fail_case "pools not empty: $pend/$que"
fi
pass_case "gauge=k($k) again, meter=$m (second sweep), pools empty"
