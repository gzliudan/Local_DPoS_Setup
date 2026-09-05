#!/bin/bash
# T09 — at-floor execution on the pre-fork tier: S3 sends at exactly 12.5 gwei.
source "$(dirname "$0")/gas2500x-lib.sh"
begin_case "T09" "seal a tx at the pre-fork floor of 12.5 gwei" 2.1

# the pre-send head is needed below for the seal-latency window, so the
# pre-fork guard is spelled out instead of require_pre_fork
head=$(head3)
[ "$head" -lt "$FORK_BLOCK" ] || skip_case "head $head >= fork $FORK_BLOCK; run before the fork"

S3_TO=$(addr_of TXGEN_KEY_1)   # send to S1's address; nonce 0 probe of S3
hash=$(send_from TXGEN_KEY_3 "$S3_TO" 1000000000000 "$GAS50_WEI")
[ -n "$hash" ] || fail_case "send rejected"

status=$(hex2dec "$(receipt_field "$hash" status)")
eff=$(hex2dec "$(receipt_field "$hash" effectiveGasPrice)")
blocknum=$(hex2dec "$(receipt_field "$hash" blockNumber)")

[ "$status" = "1" ] || fail_case "status=$status"
[ "$eff" = "$GAS50_WEI" ] || fail_case "effectiveGasPrice=$eff != $GAS50_WEI"
[ $((blocknum - head)) -le 2 ] || fail_case "sealed late: head=$head block=$blocknum"
pass_case "sealed in block $blocknum at $eff wei"
