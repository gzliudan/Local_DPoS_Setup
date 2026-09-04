#!/bin/bash
# T14 — txpool_contentFrom mirrors the queue on both sides (#2532).
# Usage: t14.sh pre|post
source "$(dirname "$0")/gas2500x-lib.sh"
begin_case "T14" "txpool_contentFrom mirrors the queue (${1:-?} side)"

side=${1:-pre}
S1=$(addr_of TXGEN_KEY_1)
content=$(rpc3 txpool_contentFrom "[\"$S1\"]")
pend=$(printf '%s' "$content" | jq '[.pending[][]] | length')
que=$(printf '%s' "$content" | jq '[.queued[][]] | length')
case "$side" in
pre)  [ "$que" = "60" ] || fail_case "pre: queued=$que, expected 60"
      [ "$pend" = "0" ] || fail_case "pre: pending=$pend" ;;
post) [ "$que" = "0" ] || fail_case "post: queued=$que, expected 0 after the sweep" ;;
*)    fail_case "usage: $0 pre|post" ;;
esac
pass_case "contentFrom: pending=$pend queued=$que"
