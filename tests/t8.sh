#!/bin/bash
# T8 — same-nonce replacement accepted (pre-fork, #2541):
# P2 (>= 1.1 x P1) replaces P1 in the queue and in the tracker.
source "$(dirname "$0")/gas2500x-lib.sh"
begin_case "T08" "same-nonce replacement accepted (pre-fork)"

h=$(head3)
[ "$h" -lt "$FORK_BLOCK" ] || skip_case "head $h >= fork $FORK_BLOCK; run before the fork"

S2=$(addr_of TXGEN_KEY_2)
S2_TO=$(addr_of TXGEN_KEY_1)

# P1 at nonce 10 (12.5 gwei) — queued behind T6's gap nonces 0..1 and T6's
# own 2..9, within the pending+10 cap; tracked by the tracker.
h1=$(send_from TXGEN_KEY_2 "$S2_TO" 1 "$GAS50_WEI" 10)
[ -n "$h1" ] || fail_case "P1 rejected"

# P2 at the same nonce 10 with a 12% bump (14 gwei; threshold is 110%)
h2=$(send_from TXGEN_KEY_2 "$S2_TO" 1 $((GAS50_WEI * 112 / 100)) 10)
[ -n "$h2" ] || fail_case "P2 rejected"
printf '%s\n%s\n' "$h1" "$h2" >/tmp/g2500-t8-hashes

# the pool's nonce-10 slot must hold only P2
content=$(rpc3 txpool_contentFrom "[\"$S2\"]")
p2hash=$(printf '%s' "$content" | jq -r '.. | .hash? // empty' | grep -i "$h2" | head -n 1)
[ -n "$p2hash" ] || fail_case "P2 ($h2) not in pool"
p1hash=$(printf '%s' "$content" | jq -r '.. | .hash? // empty' | grep -i "$h1" | head -n 1)
[ -z "$p1hash" ] || fail_case "P1 ($h1) still in pool"
pass_case "P2 replaced P1 at nonce 10"
