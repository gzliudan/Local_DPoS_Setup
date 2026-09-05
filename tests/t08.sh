#!/bin/bash
# T08 — same-nonce replacement accepted (pre-fork, #2541):
# P2 (>= 1.1 x P1) replaces P1 in the queue and in the tracker.
source "$(dirname "$0")/gas2500x-lib.sh"
begin_case "T08" "same-nonce replacement accepted (pre-fork)" 0.0

require_pre_fork

S2=$(addr_of TXGEN_KEY_2)
S2_TO=$(addr_of TXGEN_KEY_1)

# P1 at nonce 10 (12.5 gwei) — queued behind T06's gap nonces 0..1 and T06's
# own 2..9, within the pending+10 cap; tracked by the tracker.
h1=$(send_from TXGEN_KEY_2 "$S2_TO" 1 "$GAS50_WEI" 10)
[ -n "$h1" ] || fail_case "P1 rejected"

# P2 at the same nonce 10 with a 12% bump (14 gwei; threshold is 110%)
h2=$(send_from TXGEN_KEY_2 "$S2_TO" 1 $((GAS50_WEI * 112 / 100)) 10)
[ -n "$h2" ] || fail_case "P2 rejected"
printf '%s\n%s\n' "$h1" "$h2" >/tmp/g2500-t8-hashes   # consumed by T09

# the pool's nonce-10 slot must hold only P2
hashes=$(pool_hashes_from "$S2")
printf '%s' "$hashes" | grep -qi "$h2" || fail_case "P2 ($h2) not in pool"
printf '%s' "$hashes" | grep -qi "$h1" && fail_case "P1 ($h1) still in pool"
pass_case "P2 replaced P1 at nonce 10"
