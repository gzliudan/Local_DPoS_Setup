#!/bin/bash
# T32 — same-nonce replacement accepted on the new tier (#2541).
source "$(dirname "$0")/gas2500x-lib.sh"
begin_case "T32" "replace a post-fork queued tx at the same nonce" 0.1

S2=$(addr_of TXGEN_KEY_2)
S2_TO=$(addr_of TXGEN_KEY_1)

# after the sweep S2's pending nonce is 0; nonce 3 parks P1 in the queue.
h1=$(send_from TXGEN_KEY_2 "$S2_TO" 1 "$GAS2500_WEI" 3)
[ -n "$h1" ] || fail_case "P1 rejected"
# 110.4% bump (552/500) — replacement needs strictly more than 10%
h2=$(send_from TXGEN_KEY_2 "$S2_TO" 1 $((GAS2500_WEI * 552 / 500)) 3)
[ -n "$h2" ] || fail_case "P2 rejected"

hashes=$(pool_hashes_from "$S2")
p1in=$(printf '%s' "$hashes" | grep -ci "$h1")
[ "$p1in" = "0" ] || fail_case "P1 still in pool"
p2in=$(printf '%s' "$hashes" | grep -ci "$h2")
[ "$p2in" = "1" ] || fail_case "P2 not in pool"
pass_case "P2 replaced P1 at nonce 3 (625g tier)"
