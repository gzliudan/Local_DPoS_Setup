#!/bin/bash
# T7 — the queued batch is not sealed: blocks stay empty while txs sit queued.
source "$(dirname "$0")/gas2500x-lib.sh"
begin_case "T7" "the queued batch is not sealed"

head0=$(head3)
for i in $(seq 1 10); do
    wait_head $((head0 + i)) 30 || fail_case "head did not advance to $((head0 + i))"
    cnt=$(hex2dec "$(rpc3 eth_getBlockTransactionCountByNumber \
        "[\"$(printf '0x%x' $((head0 + i)))\"]" | jq -r .)")
    [ "$cnt" = "0" ] || fail_case "block $((head0 + i)) has $cnt txs"
done
pass_case "10 consecutive empty blocks"
