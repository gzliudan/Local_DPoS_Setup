#!/bin/bash
# T34 — an above-floor pre-fork transaction survives the fork sweep (#2532).
#
# pre:  S4 parks nonce 1 at 700 gwei in the queue (nonce 0 stays missing, so
#       masternodes cannot seal it); 700 gwei is admitted under the 12.5 gwei
#       pre-fork floor and is the only tx in any pool priced above the new
#       625 gwei one at the fork — the sweep must keep it (T17 asserts that).
# post: filling the gap at the new floor promotes the survivor and it seals
#       at its OWN 700 gwei price — the sweep only drops, it never reprices.
#
# The runner places t34-post right after t17 and well before t29's rewind so
# the seal blocks are re-imported by t30's sync (its wait target is fork+20
# for exactly this reason).
# Usage: t34.sh pre|post
source "$(dirname "$0")/gas2500x-lib.sh"
begin_case "T34" "above-floor pre-fork tx survives the sweep (${1:-?} side)"

side=${1:-pre}
fork_side "$side"

S4_ADDR=$(addr_of TXGEN_KEY_4)
S4_TO=$(addr_of TXGEN_KEY_1)
MARKER=/tmp/g2500-t34-hashes
SURVIVOR_WEI=700000000000    # 700 gwei — strictly above the 625 gwei floor

if [ "$side" = pre ]; then
    # pending-side txs are mined within seconds; the queue behind a nonce gap
    # is the only place a tx survives to the fork
    nonce=$(pending_nonce "$S4_ADDR")
    hash=$(send_from TXGEN_KEY_4 "$S4_TO" 1 "$SURVIVOR_WEI" "$((nonce + 1))")
    [ -n "$hash" ] || fail_case "send rejected"
    que=$(content_from "$S4_ADDR" | jq '.queued | length')
    [ "$que" = "1" ] || fail_case "S4 tx not queued (queued=$que)"
    printf '%s\n' "$hash" >"$MARKER"
    pass_case "S4 nonce $((nonce + 1)) parked queued at $SURVIVOR_WEI wei"
fi

# post side: the pre side must have seeded the survivor on this chain
[ -f "$MARKER" ] || skip_case "no T34 pre side on this chain (no $MARKER)"
hash=$(tail -n 1 "$MARKER")
gap=$(send_from TXGEN_KEY_4 "$S4_TO" 1 "$GAS2500_WEI" "$(pending_nonce "$S4_ADDR")")
[ -n "$gap" ] || fail_case "gap fill rejected"

status=$(hex2dec "$(receipt_field "$hash" status 60)")
eff=$(hex2dec "$(receipt_field "$hash" effectiveGasPrice 5)")
blocknum=$(hex2dec "$(receipt_field "$hash" blockNumber 5)")
[ "$status" = "1" ] || fail_case "survivor not sealed (status=$status)"
[ "$eff" = "$SURVIVOR_WEI" ] || fail_case "effectiveGasPrice=$eff != $SURVIVOR_WEI"
pass_case "survivor sealed in block $blocknum at $eff wei"
