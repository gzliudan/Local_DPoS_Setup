#!/bin/bash
# T31 — the post-fork reject is not tracked (#2541).
source "$(dirname "$0")/gas2500x-lib.sh"
begin_case "T31" "verify the post-fork reject is not tracked" 130.0

# give the tracker one full recheck to settle the pre-fork remnant (the tx
# journalled by T13 is EXPECTED to land in hold-back at the next recheck);
# stability is then asserted across a further full recheck window.
sleep 65
before=$(journal_size)
k=$(gauge3 txpool_local_belowfloor)

sleep 65   # one more tracker rotation — the window under test

after=$(journal_size)
k2=$(gauge3 txpool_local_belowfloor)
[ "$before" = "$after" ] || fail_case "journal grew: $before -> $after"
[ "$k2" = "$k" ] || fail_case "gauge moved: $k -> $k2"
pass_case "journal $before bytes unchanged, gauge stable at k($k)"
