#!/bin/bash
# gas2500x-run.sh — run the full gas2500x test schedule.
#
# One run is the complete test job: stop every node, wipe the datadirs,
# start a fresh network, run all cases in order, then stop the network
# (data and logs are kept; restart with ./start-network.sh && ./run-node.sh 3).
# Transcript: "start: cases=N", per-case "Tnn: test number=<head>
# expected=<n.n>s name=<case>" lines followed by verdict lines
# "Tnn: pass/fail/skip number=<head> elapsed=<n.n>s result=<evidence>",
# and "end: pass=X fail=Y skip=Z" — recorded in results/gas2500x-<ts>.log.
# expected= is embedded in each case script (its last measured wall time);
# elapsed= is measured by the lib.
set -uo pipefail
cd "$(dirname "$0")" || exit

# ---------------------------------------------------------------- lifecycle
# stop everything, wipe, restart a fresh network — before the log
# redirection so bootstrap chatter stays out of the transcript.
./stop-network.sh >/dev/null 2>&1 || true
./stop-rpc.sh >/dev/null 2>&1 || true
./reset.sh >/dev/null
./start-network.sh >/dev/null
./run-node.sh 3 >/dev/null

# the run is tee'd into the log file while staying live on the console
mkdir -p results
LOG="results/gas2500x-$(date +%Y%m%d-%H%M%S).log"
export RUN_LOG="$LOG"   # the transcript-grepping case (t35) reads sibling verdicts
source tests/gas2500x-lib.sh

echo "gas2500x test run $(date '+%F %T') — fork at block $FORK_BLOCK"
echo "log: $LOG"
echo

# everything from here on is date-time stamped into the log
stamp_lines() {
    while IFS= read -r line; do
        printf '%(%F %T)T %s\n' -1 "$line"
    done
}
exec > >(stamp_lines | tee "$LOG") 2>&1

# the tee creates $LOG asynchronously — wait briefly for it
for _ in $(seq 1 50); do
    [ -f "$LOG" ] && break
    sleep 0.1
done

# gates: pn3 RPC up within 30 s, then head past genesis within 30 s —
# T01 must not open on number=0.
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

# SCHEDULE runs t01 -> t53 in ID order; the ID IS the execution position.
# The five ranges below note the semantic chains each case relies on; the
# in-case guards still enforce the fork windows, so a missed window can
# never silently break a case (it skips or fails on its own).
#   R1 pre-fork (t01 ... t23): T01 funds every sender first; the rejects
#      (T02, T07, T08) land inside T10's 65 s tracker window, which needs
#      a clean journal/gauge; T10 precedes the seeds T11/T12 (they would
#      move both); T12 < T13 < T20 < T21 (seed -> replacement -> journal
#      convergence -> survivor park); every seal precedes T22's
#      empty-block watch; T23 closes the range across the fork.
#   R2 fork sweep (t24 ... t34): T21's parked survivor stays queued
#      through T24's sweep and is sealed by T30; T25/T26 read the sweep
#      meter/gauge before the T33 restart resets the meter; T27's reject
#      and the T29/T30 seals precede T31's 130 s journal window; T32's
#      replacement feeds T33's journal load; T34 closes the range.
#   R3 post-fork probes (t35 ... t42): read-only checks over the new
#      tier; T35 greps earlier pass verdicts from the transcript
#      (order-free by construction).
#   R4 rewind saga (t43 ... t45): T43 -> T44 -> T45 is a fixed state
#      chain (marker + isolated node hand-off); the head gate is
#      disarmed once after T43's --set-head rewind.
#   R5 creation matrix (t46 ... t53): every case fetches its own pending
#      nonce, so the eight cases are mutually independent.
SCHEDULE=(
    t01 t02 t03 t04 t05 t06 t07 t08 t09 t10 t11 t12 t13 t14 t15 t16 t17 t18 t19 t20 t21 t22 t23 t24 t25 t26 t27 t28 t29 t30 t31 t32 t33 t34 t35 t36 t37 t38 t39 t40 t41 t42 t43 t44 t45 t46 t47 t48 t49 t50 t51 t52 t53
)

if [ $# -gt 0 ]; then
    echo "error: this runner executes the full schedule only; per-case arguments were removed"
    exit 2
fi

# first line of the log
echo "start: cases=${#SCHEDULE[@]}"

passed=0
failed=0
skipped=0
# inter-case gate: each verdict carries its verdict-time head ("number=");
# the next case waits for pn3's head to move strictly past it, keeping
# test numbers strictly increasing.
prev_num=""
for item in "${SCHEDULE[@]}"; do
    f="tests/$item.sh"
    if [ ! -x "$f" ]; then
        echo "skip $item (no $f)"
        skipped=$((skipped + 1))
        continue
    fi
    # T43 disarms the gate once (see below); missing scripts skip above
    # without consuming it.
    if [[ "$prev_num" =~ ^[0-9]+$ ]]; then
        t=0
        while :; do
            head=$(head3)
            # -1 = RPC down; the case will fail on its own guards
            [ "$head" = "-1" ] && break
            [ "$head" -gt "$prev_num" ] && break
            [ "$t" -ge 30 ] && break   # stalled — proceed anyway
            sleep 1
            t=$((t + 1))
        done
    fi
    # each case prints its own verdict line; the last one matching this
    # case's id decides the tally (a crash without a verdict counts as
    # failed — skip exits 0, so rc alone cannot separate pass from skip)
    # the id IS the schedule item with its leading t uppercased
    # (t01 -> T01); the numeric printf logic died with the suffixing
    case_id="${item^}"
    # the test line (with the case's own embedded expectation) and the
    # verdict line are printed by the lib's case frame
    # the verdict search only sees lines this case produced (twice-cases)
    mark=$(wc -l <"$LOG" 2>/dev/null || echo 0)
    bash "$f"
    # poll briefly: the verdict lands in $LOG asynchronously
    verdict=""
    for _ in $(seq 1 15); do
        verdict=$(tail -n +"$((mark + 1))" "$LOG" 2>/dev/null |
            grep -E " $case_id: (pass|fail|skip)" | tail -n 1)
        [ -n "$verdict" ] && break
        sleep 0.2
    done
    # T43 rewinds the chain (--set-head 30), so its number= can never be
    # advanced past — disarm the gate once for T44.
    new_num=$(printf '%s' "$verdict" | grep -o ' number=[0-9]*' | head -n 1 | cut -d= -f2)
    if [ "$item" = "t43" ]; then
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

# stop the network when the run is done
./stop-network.sh >/dev/null 2>&1 || true
./stop-rpc.sh >/dev/null 2>&1 || true

# last line of the log
echo "end: pass=$passed fail=$failed skip=$skipped"

[ "$failed" = "0" ] || exit 1
