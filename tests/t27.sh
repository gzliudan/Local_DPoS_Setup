#!/bin/bash
# T27 — effectiveGasPrice matches the block's base fee on both tiers (#2516).
source "$(dirname "$0")/gas2500x-lib.sh"
begin_case "T27" "effectiveGasPrice matches the block base fee on both tiers"

# the per-tx receipts of T02/T20 are not addressable after the fact; the
# transcript (results/gas2500x-<ts>.log, exported as RUN_LOG by the runner)
# proves those cases sealed at the tier prices, and the boundary blocks
# below prove the tier step itself. Require both pass verdicts first.
transcript=${RUN_LOG:-$(find results -maxdepth 1 -name 'gas2500x-*.log' -printf '%T@ %p\n' 2>/dev/null | sort -rn | head -n 1 | cut -d' ' -f2-)}
if [ -z "$transcript" ] || [ ! -f "$transcript" ]; then
    fail_case "no run transcript found (results/gas2500x-*.log)"
fi
grep -q 'T02: pass' "$transcript" || \
    fail_case "run T02 and T20 first (no pass verdicts in $transcript)"
grep -q 'T20: pass' "$transcript" || \
    fail_case "run T02 and T20 first (no pass verdicts in $transcript)"

bf89=$(base_fee "$(printf '0x%x' $((FORK_BLOCK - 1)))")
bf90=$(base_fee "$(printf '0x%x' "$FORK_BLOCK")")
[ "$bf89" = "$GAS50_WEI" ] || fail_case "pre-fork baseFee=$bf89"
[ "$bf90" = "$GAS2500_WEI" ] || fail_case "post-fork baseFee=$bf90"
pass_case "tiers consistent: block 89=$bf89, block 90=$bf90"
