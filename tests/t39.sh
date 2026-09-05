#!/bin/bash
# T39 — the tier step is visible across the fork boundary blocks: fork-1
# carries the 12.5 gwei base fee, fork carries 625 gwei, #2516.
# (The pre-fork half of this check is T05.)
source "$(dirname "$0")/gas2500x-lib.sh"
begin_case "T39" "verify the block baseFeePerGas carries the tier price (post-fork tier)" 0.0

# no guard: the runner schedules this well after the fork

bf=$(base_fee latest)
[ "$bf" = "$GAS2500_WEI" ] || fail_case "latest baseFee=$bf, expected $GAS2500_WEI"
bf_pre=$(base_fee "$(printf '0x%x' $((FORK_BLOCK - 1)))")
bf_fork=$(base_fee "$(printf '0x%x' "$FORK_BLOCK")")
[ "$bf_pre" = "$GAS50_WEI" ] || fail_case "block $((FORK_BLOCK - 1)) baseFee=$bf_pre"
[ "$bf_fork" = "$GAS2500_WEI" ] || fail_case "block $FORK_BLOCK baseFee=$bf_fork"
pass_case "baseFeePerGas=$bf wei (step $((FORK_BLOCK - 1))→$FORK_BLOCK visible)"
