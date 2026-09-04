#!/bin/bash
# T12 — eth_getBlockByNumber baseFeePerGas on both sides of the fork (#2516).
# Usage: t12.sh pre|post
source "$(dirname "$0")/gas2500x-lib.sh"
begin_case "T12" "eth_getBlockByNumber baseFeePerGas (${1:-?} side)"

side=${1:-pre}
fork_side "$side"
want=$(tier_for "$side")

bf=$(base_fee latest)
[ "$bf" = "$want" ] || fail_case "latest baseFee=$bf, expected $want"
if [ "$side" = "post" ]; then
    # the tier step is visible across the fork boundary blocks
    bf89=$(base_fee "$(printf '0x%x' $((FORK_BLOCK - 1)))")
    bf90=$(base_fee "$(printf '0x%x' "$FORK_BLOCK")")
    [ "$bf89" = "$GAS50_WEI" ] || fail_case "block $((FORK_BLOCK - 1)) baseFee=$bf89"
    [ "$bf90" = "$GAS2500_WEI" ] || fail_case "block $FORK_BLOCK baseFee=$bf90"
fi
pass_case "baseFeePerGas=$bf wei (step 89→90 visible)"
