#!/bin/bash
# T23 — same-nonce replacement accepted on the new tier (#2541).
source "$(dirname "$0")/gas2500x-lib.sh"
begin_case "T23" "same-nonce replacement accepted on the new tier"

S2=$(addr_of TXGEN_KEY_2)
S2_TO=$(addr_of TXGEN_KEY_1)

# after the sweep S2's pending nonce is 0; nonce 3 parks P1 in the queue.
h1=$(send_from TXGEN_KEY_2 "$S2_TO" 1 "$GAS2500_WEI" 3)
[ -n "$h1" ] || fail_case "P1 rejected"
h2=$(send_from TXGEN_KEY_2 "$S2_TO" 1 $((GAS2500_WEI * 110 / 100)) 3)
[ -n "$h2" ] || fail_case "P2 rejected"

grep -q "Replaced tracked local transaction" logs/pn3-*.log 2>/dev/null \
    || fail_case "no replacement log"

content=$(rpc3 txpool_contentFrom "[\"$S2\"]")
p1in=$(printf '%s' "$content" | jq -r '.. | .hash? // empty' | grep -ci "$h1")
[ "$p1in" = "0" ] || fail_case "P1 still in pool"
p2in=$(printf '%s' "$content" | jq -r '.. | .hash? // empty' | grep -ci "$h2")
[ "$p2in" = "1" ] || fail_case "P2 not in pool"
pass_case "P2 replaced P1 at nonce 3 (625g tier)"
