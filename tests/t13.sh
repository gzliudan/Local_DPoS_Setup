#!/bin/bash
# T13 — eth_sendTransaction without gasPrice on both sides (#2516):
# the node signs P3's tx with the tier-aware default price.
# Usage: t13.sh pre|post  (P3 = pn3's unlocked keystore account, PRIVATE_KEY_3)
source "$(dirname "$0")/gas2500x-lib.sh"
begin_case "T13" "eth_sendTransaction without gasPrice (${1:-?} side)"

side=${1:-pre}
case "$side" in
pre)  want=$GAS50_WEI ;;
post) want=$GAS2500_WEI ;;
*)    fail_case "usage: $0 pre|post" ;;
esac

P3_TO=$(addr_of TXGEN_KEY_1)
# P3 signs from pn3's unlocked keystore (PRIVATE_KEY_3 is the node's own key)
hash=$(cast send "$P3_TO" --value 1wei --gas-limit 21000 \
    --private-key "$(printenv PRIVATE_KEY_3)" --rpc-url "$RPC3" \
    --chain-id "$CHAIN_ID" --json 2>/dev/null | jq -r .transactionHash)
if [ -z "$hash" ] || [ "$hash" = "null" ]; then
    fail_case "send rejected"
fi

eff=$(hex2dec "$(receipt_field "$hash" effectiveGasPrice)")
[ "$eff" = "$want" ] || fail_case "effectiveGasPrice=$eff, expected $want"
pass_case "default-price tx sealed at $eff wei"
