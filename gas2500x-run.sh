#!/bin/bash
# gas2500x-run.sh — run all gas2500x test cases in order and summarize.
#
# Usage: gas2500x-run.sh [t1 t2 ...]   (default: all cases in execution order)
# Results: a fresh results/gas2500x-results-<timestamp>.md per run (one
# markdown table row per case) plus a printed summary table; earlier result
# files are never overwritten or appended to.
set -uo pipefail
cd "$(dirname "$0")" || exit

# one results file per run: pre-set RESULTS_FILE before sourcing the lib and
# export it so each case script (separate bash process) inherits the same file
ts=$(date +%Y%m%d-%H%M%S)
RESULTS_FILE="$PWD/results/gas2500x-results-$ts.md"
n=1
while [ -e "$RESULTS_FILE" ]; do
    RESULTS_FILE="$PWD/results/gas2500x-results-$ts-$n.md"
    n=$((n + 1))
done
export RESULTS_FILE

# create the per-run file up front with the table header, so the header is
# always there and the summary tail succeeds even when every case skips
mkdir -p results
printf '| Case | Name | Status | Block | Evidence |\n|---|---|---|---|---|\n' > "$RESULTS_FILE"

source tests/gas2500x-lib.sh

# the twice-cases run their pre side before the fork and their post side after
declare -A RUN=(
    [t10-pre]="t10 pre"   [t10-post]="t10 post"
    [t11-pre]="t11 pre"   [t11-post]="t11 post"
    [t12-pre]="t12 pre"   [t12-post]="t12 post"
    [t13-pre]="t13 pre"   [t13-post]="t13 post"
    [t14-pre]="t14 pre"   [t14-post]="t14 post"
    [t15-pre]="t15 pre"   [t15-post]="t15 post"
)
# full ordered schedule: id = script (empty = pre/post instance of a script)
SCHEDULE=(
    t1 t2 t3 t4 t5 t6 t7 t8 t9
    t10-pre t11-pre t12-pre t13-pre t14-pre t15-pre
    t16 t17 t18 t19
    t20 t21 t22 t23 t24 t25 t26 t27 t28
    t10-post t11-post t12-post t13-post t14-post t15-post
    t29 t30 t31
)

if [ $# -gt 0 ]; then
    SCHEDULE=("$@")
fi

echo "gas2500x test run $(date '+%F %T') — fork at block $FORK_BLOCK"
echo "results: $RESULTS_FILE"
echo

failed=0
passed=0
for item in "${SCHEDULE[@]}"; do
    script=${RUN[$item]:-$item}
    label=${RUN[$item]:+$item}
    args=""
    if [ -n "$label" ]; then
        script=${item%-*}
        args=${item#*-}
    fi
    f="tests/$script.sh"
    [ -x "$f" ] || { echo "SKIP $item (no $f)"; continue; }
    if bash "$f" "$args"; then
        passed=$((passed + 1))
    else
        failed=$((failed + 1))
    fi
done

echo
echo "==================== summary ===================="
printf 'passed=%d failed=%d\n' "$passed" "$failed"
echo
echo "| Case | Status | Evidence |"
echo "|---|---|---|"
tail -n ${#SCHEDULE[@]} "$RESULTS_FILE" | grep '^| T' | tail -n ${#SCHEDULE[@]} |
    awk -F'|' '{gsub(/^ +| +$/,"",$2); printf "| %s | %s |%s\n", $2, $5, $6}'
[ "$failed" = "0" ] || exit 1
