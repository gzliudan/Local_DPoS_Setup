#!/bin/bash
# T13 — eth_sendTransaction without gasPrice on both sides (#2516):
# the node signs P3's tx with the tier-aware default price.
# Usage: t13.sh pre|post  (P3 = pn3's unlocked keystore account, PRIVATE_KEY_3)
source "$(dirname "$0")/gas2500x-lib.sh"
begin_case "T13" "eth_sendTransaction without gasPrice (${1:-?} side)"

side=${1:-pre}
if [ "$side" = "pre" ]; then
    h=$(head3)
    [ "$h" -lt "$FORK_BLOCK" ] || skip_case "head $h >= fork $FORK_BLOCK; pre side missed the window"
fi
case "$side" in
pre)  want=$GAS50_WEI ;;
post) want=$GAS2500_WEI ;;
*)    fail_case "usage: $0 pre|post" ;;
esac

P3_TO=$(addr_of TXGEN_KEY_1)
# P3 signs from pn3's unlocked keystore (PRIVATE_KEY_3 is the node's own key);
# --legacy keeps the price assertion exact (a 1559 tx's effectiveGasPrice
# would still be the base fee, but legacy is what the plan documents)
hash=$(cast send "$P3_TO" --value 1wei --gas-limit 21000 --legacy \
    --private-key "$(printenv PRIVATE_KEY_3)" --rpc-url "$RPC3" \
    --chain-id "$CHAIN_ID" --json --async 2>/dev/null)
case "$hash" in 0x*) ;; *) fail_case "send rejected" ;; esac

eff=$(hex2dec "$(receipt_field "$hash" effectiveGasPrice)")
[ "$eff" = "$want" ] || fail_case "effectiveGasPrice=$eff, expected $want"
pass_case "default-price tx sealed at $eff wei"
