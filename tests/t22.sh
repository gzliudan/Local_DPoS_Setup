#!/bin/bash
# T22 — the post-fork reject is not tracked (#2541).
source "$(dirname "$0")/gas2500x-lib.sh"
begin_case "T22" "the post-fork reject is not tracked"

# give the tracker one full recheck to settle the pre-fork remnant (the tx
# journalled by T8 is EXPECTED to land in hold-back at the next recheck);
# stability is then asserted across a further full recheck window.
sleep 65
before=$(journal_size)
k=$(meter3 txpool_local_belowfloor); k=${k:-0}

sleep 65   # one more tracker rotation — the window under test

after=$(journal_size)
k2=$(meter3 txpool_local_belowfloor); k2=${k2:-0}
[ "$before" = "$after" ] || fail_case "journal grew: $before -> $after"
[ "$k2" = "$k" ] || fail_case "gauge moved: $k -> $k2"
pass_case "journal $before bytes unchanged, gauge stable at k($k)"
