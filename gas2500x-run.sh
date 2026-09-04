#!/bin/bash
# gas2500x-run.sh — run all gas2500x test cases in order and summarize.
#
# Usage: gas2500x-run.sh [t1 t2 ...]   (default: all cases in execution order)
# Results: printed to stdout, every line prefixed with the current date-time —
# each case emits its own "Tn: pass/fail/skip - evidence" line as it
# runs, and the runner prints a summary table at the end. The stamped console
# output is also recorded in results/gas2500x-<timestamp>.log; no results
# .md file is created.
# When the run finishes the network is stopped (all nodes) — the suite owns
# the whole lifecycle; start it again with ./start-network.sh && ./run-node.sh 3.
set -uo pipefail
cd "$(dirname "$0")" || exit

# record the whole run in results/gas2500x-<timestamp>.log while keeping the
# live console view (tee): stdout+stderr of everything below lands in the file
mkdir -p results
LOG="results/gas2500x-$(date +%Y%m%d-%H%M%S).log"
export RUN_LOG="$LOG"   # case scripts (t27) read sibling verdicts from it
source tests/gas2500x-lib.sh

echo "gas2500x test run $(date '+%F %T') — fork at block $FORK_BLOCK"
echo "log: $LOG"
echo

# from here on everything (stdout+stderr) is duplicated into the log file and
# every line is prefixed with the current date-time; the banner above stays
# console-only, so the log starts at the first case
stamp_lines() {
    while IFS= read -r line; do
        printf '%(%F %T)T %s\n' -1 "$line"
    done
}
exec > >(stamp_lines | tee "$LOG") 2>&1

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

failed=0
passed=0
rows=()
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
    # stream the case output live through the stamp filter — capturing it in
    # a variable would print every line at case end and stamp identical
    # times on the start and verdict lines. The verdict is recovered from
    # the transcript (each line is "date time Tnn: status - evidence").
    id_num=${item%%-*}; id_num=${id_num#t}
    case_id=$(printf 'T%02d' "$id_num")
    bash "$f" "$args"
    rc=$?
    if [ "$rc" -eq 0 ]; then
        passed=$((passed + 1))
    else
        failed=$((failed + 1))
    fi
    verdict=$(grep -E " $case_id: (pass|fail|skip)" "$LOG" 2>/dev/null | tail -n 1)
    if [ -n "$verdict" ]; then
        rows+=("$verdict")
    else
        rows+=("$item - no verdict line")
    fi
done

echo
echo "==================== summary ===================="
printf 'passed=%d failed=%d\n' "$passed" "$failed"
echo
echo "| Case | Status | Evidence |"
echo "|---|---|---|"
for row in "${rows[@]}"; do
    # "2026-09-04 23:39:14 T02: pass output=evidence ..." ->
    # | T02 | pass | evidence ... |
    printf '%s\n' "$row" | awk '
        {
            sub(/^[0-9-]+ [0-9:]+ /, "")   # drop the date-time stamp
            split($0, h, " ")              # h: [T02:, pass, output=evidence ...]
            id = h[1]; sub(/:$/, "", id)
            status = h[2]
            ev = $0
            sub(/^[^ ]+ [^ ]+ output=/, "", ev)   # everything after "output="
            printf "| %s | %s | %s |\n", id, status, (ev == "" ? "-" : ev)
        }'
done

# the suite owns the network lifecycle: stop all nodes once the run is done
echo
echo "stopping the network ..."
./stop-network.sh >/dev/null 2>&1 || true
pkill -f 'XDC --config nodes/pn3' 2>/dev/null || true   # observer is not in the .pid files
echo "network stopped"

[ "$failed" = "0" ] || exit 1
