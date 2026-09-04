#!/bin/bash
# T13 — eth_sendTransaction without gasPrice on both sides (#2516):
# the node signs P3's tx with the tier-aware default price.
# Usage: t13.sh pre|post  (P3 = pn3's unlocked keystore account, PRIVATE_KEY_3)
source "$(dirname "$0")/gas2500x-lib.sh"
begin_case "T13" "eth_sendTransaction without gasPrice (${1:-?} side)"

side=${1:-pre}
fork_side "$side"
want=$(tier_for "$side")

P3_TO=$(addr_of TXGEN_KEY_1)
# signed locally with P3's own key (PRIVATE_KEY_3, the node's keystore
# account); NO --gas-price: cast omits the price and the node fills the
# tier-aware default. --legacy keeps the price assertion exact (a 1559 tx's
# effectiveGasPrice would still be the base fee, but legacy is what the plan
# documents)
hash=$(_cast_send "$RPC3" PRIVATE_KEY_3 "$P3_TO" 1 "" "" --async 2>/dev/null)
case "$hash" in 0x*) ;; *) fail_case "send rejected" ;; esac

eff=$(hex2dec "$(receipt_field "$hash" effectiveGasPrice)")
[ "$eff" = "$want" ] || fail_case "effectiveGasPrice=$eff, expected $want"
pass_case "default-price tx sealed at $eff wei"
