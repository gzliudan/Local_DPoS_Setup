#!/bin/bash
# T8 — same-nonce replacement accepted (pre-fork, #2541):
# P2 (>= 1.1 x P1) replaces P1 in the queue and in the tracker.
source "$(dirname "$0")/gas2500x-lib.sh"
begin_case "T8" "same-nonce replacement accepted (pre-fork)"

S2=$(addr_of TXGEN_KEY_2)
S2_TO=$(addr_of TXGEN_KEY_1)

# P1 at nonce 20 (12.5 gwei) — queued behind the gap nonces 0..19, tracked.
h1=$(send_from TXGEN_KEY_2 "$S2_TO" 1 "$GAS50_WEI" 20)
[ -n "$h1" ] || fail_case "P1 rejected"

# P2 at the same nonce 20 with >= 10% bump (14 gwei).
h2=$(send_from TXGEN_KEY_2 "$S2_TO" 1 $((GAS50_WEI * 112 / 100)) 20)
[ -n "$h2" ] || fail_case "P2 rejected"

# the tracker log must record the replacement
grep -q "Replaced tracked local transaction" logs/pn3-*.log 2>/dev/null \
    || fail_case "no 'Replaced tracked local transaction' in pn3 logs"

# the pool's nonce-20 slot must hold only P2
content=$(rpc3 txpool_contentFrom "[\"$S2\"]")
p2hash=$(printf '%s' "$content" | jq -r '.. | .hash? // empty' | grep -i "$h2" | head -n 1)
[ -n "$p2hash" ] || fail_case "P2 ($h2) not in pool"
p1hash=$(printf '%s' "$content" | jq -r '.. | .hash? // empty' | grep -i "$h1" | head -n 1)
[ -z "$p1hash" ] || fail_case "P1 ($h1) still in pool"
pass_case "P2 replaced P1 at nonce 20"
