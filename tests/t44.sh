#!/bin/bash
# T44 — the re-cross sweep fires again (#2532).
#
# T43 left pn3 isolated and rewound to 30 with the hold-backs REVIVED into
# the pool (floor 12.5 gwei). This script re-connects the node to pn0 via
# admin_addPeer (public API), lets it sync 30 -> head, crossing the fork at
# 90: the head-event sweep (#2532) must drop the revived transactions a
# SECOND time — in the SAME process, so the txpool/belowfloor meter grows to
# ~2x the first sweep and the tracker re-holds them (gauge back to k).
source "$(dirname "$0")/gas2500x-lib.sh"
begin_case "T44" "the re-cross sweep fires again"

if [ ! -f /tmp/g2500-t43-state ]; then
    skip_case "T43 revival did not run; no re-cross to observe"
fi

m0=$(gauge3 txpool_belowfloor)
enode=$(pn0_enode)
[ -n "$enode" ] || { restore_pn3; fail_case "could not fetch pn0's enode"; }

if ! rpc3 admin_addPeer "[\"$enode\"]" >/dev/null; then
    restore_pn3
    fail_case "admin_addPeer failed"
fi

# T10's above-floor pair seals a few blocks past the fork; the rewind's
# revival resubmits both (their nonces are unspent again at head 30), so the
# sync must re-import their seal blocks for the pool to drop them before the
# poll below — hence +20 instead of the old +5.
wait_head $((FORK_BLOCK + 20)) 300 || {
    restore_pn3
    fail_case "pn3 never synced past $((FORK_BLOCK + 20))"
}

# the sweep runs inside the pool's head-event handler at the crossing; the
# tracker's gauge is only updated on its next recheck (up to 60 s later).
# P2 (110.4%, above the new floor) LEGITIMATELY survives the sweep and stays
# queued behind its nonce gap — only below-floor txs are dropped, so allow
# one queued straggler.
ok=0
m=""; k=""; pools=""
for _ in $(seq 1 30); do
    sleep 3
    m=$(gauge3 txpool_belowfloor)
    k=$(gauge3 txpool_local_belowfloor)
    read -r p q <<<"$(pool3)"
    pools="$p/$q"
    if [ "$m" -ge 18 ] && [ "$k" -ge 18 ] && [ "$p" = "0" ] && [ "$q" -le 1 ]; then
        ok=1; break
    fi
done
if [ "$ok" != "1" ]; then
    restore_pn3
    fail_case "re-cross sweep incomplete: meter=$m (was $m0), gauge=$k, pools=$pools"
fi
rm -f /tmp/g2500-t43-state

pass_case "second sweep fired: meter $m0->$m, gauge=k($k), pools empty"
