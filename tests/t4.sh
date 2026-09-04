#!/bin/bash
# T4 — the below-floor reject is not tracked (#2541).
source "$(dirname "$0")/gas2500x-lib.sh"
begin_case "T4" "the below-floor reject is not tracked"

before=$(journal_size)
gauge=$(meter3 txpool_local_belowfloor); gauge=${gauge:-0}

# sleep one tracker rotation (recheck every 60 s) so a wrong implementation
# would have had time to resubmit/journal the rejected tx
sleep 65

after=$(journal_size)
gauge2=$(meter3 txpool_local_belowfloor); gauge2=${gauge2:-0}

[ "$before" = "$after" ] || fail_case "journal grew: $before -> $after"
[ "$gauge2" = "$gauge" ] || fail_case "gauge moved: $gauge -> $gauge2"
pass_case "journal $before bytes unchanged, gauge $gauge"
