#!/bin/bash
# T14 — txpool_contentFrom mirrors the queue on both sides (#2532).
# Usage: t14.sh pre|post
source "$(dirname "$0")/gas2500x-lib.sh"
begin_case "T14" "txpool_contentFrom mirrors the queue (${1:-?} side)"

side=${1:-pre}
fork_side "$side"

S1=$(addr_of TXGEN_KEY_1)
content=$(content_from "$S1")
# contentFrom(FROM) returns {pending|queued: {nonce: tx}} — a SINGLE-level
# map (flattenTxs keys by nonce); the old [.queued[][]] double-iterated into
# each tx object's fields (10 txs x 17 fields = the phantom "170")
pend=$(printf '%s' "$content" | jq '[.pending[]] | length')
que=$(printf '%s' "$content" | jq '[.queued[]] | length')
case "$side" in
pre)  [ "$que" = "10" ] || fail_case "pre: queued=$que, expected 10"
      [ "$pend" = "0" ] || fail_case "pre: pending=$pend" ;;
post) [ "$que" = "0" ] || fail_case "post: queued=$que, expected 0 after the sweep" ;;
esac
pass_case "contentFrom: pending=$pend queued=$que"
