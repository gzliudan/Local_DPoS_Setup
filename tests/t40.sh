#!/bin/bash
# T40 — txpool_contentFrom shows S1's queue empty after the fork sweep
# (queued=0), #2532. (The pre-fork half of this check is T14.)
source "$(dirname "$0")/gas2500x-lib.sh"
begin_case "T40" "verify txpool_contentFrom mirrors the queue (post-fork tier)" 0.0

# no guard: the runner schedules this well after the fork

S1=$(addr_of TXGEN_KEY_1)
content=$(content_from "$S1")
pend=$(printf '%s' "$content" | jq '[.pending[]] | length')
que=$(printf '%s' "$content" | jq '[.queued[]] | length')
[ "$que" = "0" ] || fail_case "queued=$que, expected 0 after the sweep"
pass_case "contentFrom: pending=$pend queued=$que"
