#!/bin/bash
# T15 — the tier-aware default gas price on the pre-fork tier: P3's
# transfer is signed locally with NO gas price, so the node fills in the
# tier-aware suggested price (12.5 gwei), #2516.
# (The post-fork half of this check is T42; P3 = pn3's own account,
# PRIVATE_KEY_3.)
source "$(dirname "$0")/gas2500x-lib.sh"
begin_case "T15" "the tier-aware default gas price (pre-fork tier)" 2.1

require_pre_fork "pre side missed the window"

P3_TO=$(addr_of TXGEN_KEY_1)
# signed locally with P3's own key; NO --gas-price: cast omits the price
# and the node fills the tier-aware default. --legacy keeps the price
# assertion exact (a 1559 tx's effectiveGasPrice would still be the base
# fee, but legacy is what the plan documents)
hash=$(_cast_send "$RPC3" PRIVATE_KEY_3 "$P3_TO" 1 "" "" --async 2>/dev/null)
case "$hash" in 0x*) ;; *) fail_case "send rejected" ;; esac

eff=$(hex2dec "$(receipt_field "$hash" effectiveGasPrice)")
[ "$eff" = "$GAS50_WEI" ] || fail_case "effectiveGasPrice=$eff, expected $GAS50_WEI"
pass_case "default-price tx sealed at $eff wei"
