#!/bin/bash
# gas2500x-run.sh — run all gas2500x test cases in order and summarize.
#
# Usage: gas2500x-run.sh   (runs the complete schedule; per-case arguments were removed)
# Lifecycle: a run is the complete test job — it stops any leftover nodes,
# wipes the datadirs, starts the whole network, runs the cases, and stops the
# network at the end (data and logs are kept for inspection).
# Results: printed to stdout, every line prefixed with the current date-time —
# the log opens with "start: cases=N", every case streams its
# "Tnn: pass/fail/skip number=<head> result=<evidence>" verdict line, and the log closes
# with "end: pass=X fail=Y skip=Z". The stamped console output is
# also recorded in results/gas2500x-<timestamp>.log; no results .md file
# is created.
# When the run finishes the network is stopped (all nodes) — data and logs
# are kept for inspection; restart with ./start-network.sh && ./run-node.sh 3.
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

# ---------------------------------------------------------------- lifecycle
# The suite owns the whole lifecycle so a single run of this script is the
# complete test job: stop any leftover nodes, wipe the datadirs for a fresh
# chain, start everything back up, and only then begin the cases. This runs
# BEFORE the log redirection below on purpose — the nodes' bootstrap chatter
# (genesis init, backfilled fields, peer dialing) stays on the console and
# out of the transcript. A live pn3 short-circuits this (pre-provisioned
# network; results then start from a used chain).
if [ "$(head3)" != "-1" ]; then
    LIFECYCLE="pn3 already running — kept the existing chain"
else
    ./stop-network.sh >/dev/null 2>&1 || true
    pkill -f 'XDC --config nodes/pn3' 2>/dev/null || true   # observer has no .pid file
    ./reset.sh >/dev/null
    ./start-network.sh >/dev/null
    ./run-node.sh 3 >/dev/null
    LIFECYCLE="fresh chain: reset + full network start"
fi

# from here on everything (stdout+stderr) is duplicated into the log file and
# every line is prefixed with the current date-time; the banner and the
# lifecycle bootstrap above stay console-only
stamp_lines() {
    while IFS= read -r line; do
        printf '%(%F %T)T %s\n' -1 "$line"
    done
}
exec > >(stamp_lines | tee "$LOG") 2>&1

# the tee inside the process substitution above creates the log file
# asynchronously — bash does not wait for it, so the first case could race
# past a still-missing file (seen as a "No such file or directory" on the
# mark snapshot). Wait for it, bounded.
for _ in $(seq 1 50); do
    [ -f "$LOG" ] && break
    sleep 0.1
done
echo "lifecycle: $LIFECYCLE"

# every case must start on a real, MOVING chain. The RPC answering is not
# enough: a freshly initialized chain sits at head 0 until the first seal,
# and T01 opening on number=0 would break the strict-ordering invariant.
# So: RPC up within 30 s, then head > 0 within another 30 s (1 s polls).
if ! wait_rpc3 30; then
    echo "error: pn3 RPC did not come up within 30 s"
    exit 1
fi
t=0
while :; do
    h=$(head3)
    [ "$h" -gt 0 ] 2>/dev/null && break
    [ "$t" -ge 30 ] && { echo "error: chain head never advanced past 0"; exit 1; }
    sleep 1
    t=$((t + 1))
done

# full ordered schedule: the twice-cases (t10-t15, t34) run their pre side
# before the fork and their post side after — a "<script>-<side>" entry runs
# tests/<script>.sh with the side as its argument. Ordering constraints:
# t34-pre parks the sweep survivor before the fork (t17 asserts it),
# t34-post seals it right after t17 so t30's sync re-imports the seal blocks
# before its poll, and t32/t33 submit only after the t29-t31 saga so their
# txs are never in the journal when the rewind resubmits it.
SCHEDULE=(
    t1 t2 t3 t4 t5 t6 t7 t8 t9 t34-pre
    t10-pre t11-pre t12-pre t13-pre t14-pre t15-pre
    t16 t17 t34-post t18 t19
    t20 t21 t22 t23 t24 t25 t26 t27 t28
    t10-post t11-post t12-post t13-post t14-post t15-post
    t29 t30 t31
    t32 t33
)

if [ $# -gt 0 ]; then
    echo "error: this runner executes the full schedule only; per-case arguments were removed"
    exit 2
fi

# first line of the log (the console banner above is not part of it)
echo "start: cases=${#SCHEDULE[@]}"

passed=0
failed=0
skipped=0
# block-advance gate between cases: each verdict line carries the chain head
# at verdict time ("number="), and the next case may start as soon as pn3's
# head moves strictly past it — no fixed sleep. A case ending right after a
# seal waits ~2 s, one ending right before waits ~4 s, and every
# "test number=" still lands on a strictly higher block than the previous
# case's.
prev_num=""
for item in "${SCHEDULE[@]}"; do
    if [[ "$prev_num" =~ ^[0-9]+$ ]]; then
        t=0
        while :; do
            head=$(head3)
            # -1 = pn3's RPC is down: the gate cannot be satisfied and the
            # case about to run will fail on its own guards — stop waiting
            [ "$head" = "-1" ] && break
            [ "$head" -gt "$prev_num" ] && break
            [ "$t" -ge 30 ] && break   # the chain stalled — proceed anyway
            sleep 1
            t=$((t + 1))
        done
    fi
    script=$item
    args=""
    case $item in
    t1[0-5]-* | t34-*)
        script=${item%-*}
        args=${item#*-}
        ;;
    esac
    f="tests/$script.sh"
    if [ ! -x "$f" ]; then
        echo "skip $item (no $f)"
        skipped=$((skipped + 1))
        continue
    fi
    # stream the case output live through the stamp filter — capturing it in
    # a variable would print every line at case end and stamp identical
    # times on the start and verdict lines. Each case prints its own
    # "Tnn: pass/fail/skip number=<head> result=..." verdict line; the last one matching
    # this case's id decides the tally (a case that crashes before printing
    # a verdict counts as failed — skip exits 0, so the rc alone cannot
    # separate pass from skip).
    id_num=${item%%-*}; id_num=${id_num#t}
    case_id=$(printf 'T%02d' "$id_num")
    # snapshot the log length before the case runs, so the verdict search
    # below only sees lines this case produced (a twice-case must not pick
    # up its other side's verdict)
    mark=$(wc -l <"$LOG" 2>/dev/null || echo 0)
    # wall time for the case's elapsed= field (ms resolution, rounded to 0.1 s)
    t0=$(date +%s%3N)
    bash "$f" "$args"
    elapsed_ms=$(( $(date +%s%3N) - t0 ))
    elapsed="$((elapsed_ms / 1000)).$(( (elapsed_ms % 1000) / 100 ))s"
    # the verdict travels through the stamp|tee process substitution, which
    # bash does NOT wait for — a single immediate grep can read the log
    # before the verdict line lands (seen as a phantom fail in run 16). Poll
    # briefly for it; a crash without a verdict still times out into a fail.
    verdict=""
    for _ in $(seq 1 15); do
        verdict=$(tail -n +"$((mark + 1))" "$LOG" 2>/dev/null |
            grep -E " $case_id: (pass|fail|skip)" | tail -n 1)
        # inject the elapsed field into the verdict line (after number=)
        if [ -n "$verdict" ]; then
            verdict=${verdict/ result=/ elapsed=$elapsed result=}
            break
        fi
        sleep 0.2
    done
    # remember this case's verdict-time head for the next case's gate; a
    # crashed case (no verdict, or no number= in it) leaves the previous
    # number in place instead of disabling the gate. T29 is the exception:
    # it rewinds the chain (--set-head 30), so its number= is BELOW the fork
    # and head > that number can never come true while the node is isolated —
    # disarm the gate once so T30 (which re-syncs) starts immediately.
    new_num=$(printf '%s' "$verdict" | grep -o ' number=[0-9]*' | head -n 1 | cut -d= -f2)
    if [ "$item" = "t29" ]; then
        prev_num=""
    elif [ -n "$new_num" ]; then
        prev_num=$new_num
    fi
    case $verdict in
    *" pass "*) passed=$((passed + 1)) ;;
    *" skip "*) skipped=$((skipped + 1)) ;;
    *)          failed=$((failed + 1)) ;;
    esac
done

# the suite owns the network lifecycle: stop all nodes once the run is done
# (quietly - no stop chatter in the transcript)
./stop-network.sh >/dev/null 2>&1 || true
pkill -f 'XDC --config nodes/pn3' 2>/dev/null || true   # observer is not in the .pid files

# last line of the log
echo "end: pass=$passed fail=$failed skip=$skipped"

[ "$failed" = "0" ] || exit 1
