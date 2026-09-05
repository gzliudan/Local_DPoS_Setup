#!/bin/bash
# T15 — txpool_contentFrom mirrors S1's pre-fork queue (10 queued), #2532.
# (The post-fork half of this check is T41.)
source "$(dirname "$0")/gas2500x-lib.sh"
begin_case "T15" "txpool_contentFrom mirrors the queue (pre-fork tier)" 0.0

require_pre_fork "pre side missed the window"

S1=$(addr_of TXGEN_KEY_1)
content=$(content_from "$S1")
# contentFrom(FROM) returns {pending|queued: {nonce: tx}} — a SINGLE-level
# map (flattenTxs keys by nonce); the old [.queued[][]] double-iterated into
# each tx object's fields (10 txs x 17 fields = the phantom "170")
pend=$(printf '%s' "$content" | jq '[.pending[]] | length')
que=$(printf '%s' "$content" | jq '[.queued[]] | length')
[ "$que" = "10" ] || fail_case "queued=$que, expected 10"
[ "$pend" = "0" ] || fail_case "pending=$pend"
pass_case "contentFrom: pending=$pend queued=$que"
