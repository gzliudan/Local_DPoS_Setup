#!/bin/bash
# T21 — S4 parks an above-floor (700 gwei) transfer in the queue behind a
# nonce gap; 700 gwei is admitted under the pre-fork floor and is the only
# above-625gwei tx in any pool at the fork — the sweep must keep it
# (T24 asserts that; T30 seals it post-fork). #2532
source "$(dirname "$0")/gas2500x-lib.sh"
begin_case "T21" "park a 700 gwei tx from S4 for the sweep" 0.0

require_pre_fork "pre side missed the window"

S4_ADDR=$(addr_of TXGEN_KEY_4)
S4_TO=$(addr_of TXGEN_KEY_1)
MARKER=/tmp/g2500-t21-hashes
SURVIVOR_WEI=700000000000    # 700 gwei — strictly above the 625 gwei floor

# pending-side txs are mined within seconds; the queue behind a nonce gap
# is the only place a tx survives to the fork
nonce=$(pending_nonce "$S4_ADDR")
hash=$(send_from TXGEN_KEY_4 "$S4_TO" 1 "$SURVIVOR_WEI" "$((nonce + 1))")
[ -n "$hash" ] || fail_case "send rejected"
que=$(content_from "$S4_ADDR" | jq '.queued | length')
[ "$que" = "1" ] || fail_case "S4 tx not queued (queued=$que)"
printf '%s\n' "$hash" >"$MARKER"
pass_case "S4 nonce $((nonce + 1)) parked queued at $SURVIVOR_WEI wei"
