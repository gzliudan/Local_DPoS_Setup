#!/bin/bash
# gas2500x-run.sh — run the full gas2500x test schedule.
#
# One run is the complete test job: stop every node, wipe the datadirs,
# start a fresh network, run all cases in order, then stop the network
# (data and logs are kept; restart with ./start-network.sh && ./run-node.sh 3).
# Transcript: "start: cases=N", per-case "Tnn: test number=<head>
# expected=<n>s name=<case>" lines followed by verdict lines
# "Tnn: pass/fail/skip number=<head> elapsed=<n>s result=<evidence>",
# and "end: pass=X fail=Y skip=Z" — recorded in results/gas2500x-<ts>.log.
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
export RUN_LOG="$LOG"   # case scripts (t27) read sibling verdicts from it
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

# Five dependency ranges; inside each range the cases are ordered by the
# verdict elapsed= values of results/gas2500x-20260905-122923.log (fast
# first), subject to the state chains noted per range. The guards inside
# the cases still enforce the semantic windows (pre-fork cases skip past
# the fork), so a wrong window can never silently break a case.
#   R1 pre-fork (22 cases, t01 first, t23 closes the range): T01 funds
#      every sender first; T02+T03 precede T04 (its 65 s window needs a
#      clean tracker/journal); T04 precedes T05/T06 (the seeds would move
#      the gauge); T05 < T15, T06 < T08 < T09 < T10 (queue seed ->
#      replacement -> journal convergence -> survivor park); every
#      sealing case precedes T07's empty-block watch.
#   R2 fork sweep (t23-t34): T24 before T25 (T25 seals the survivor T24
#      expects still queued); T26 before T32 (pn3's restart resets the
#      meter); T27 and T30 read gauge=k(19), so both precede T31's
#      replacement; T30's 130 s journal window needs T29's reject and
#      T25/T28's seals done; T32 < T34.
#   R3 post-fork probes (t35-t42): T35 greps the T02+T28 pass verdicts
#      from the transcript; the rest are read-only or self-contained
#      (T40's 625 gwei seal stays before T43's rewind, matching run #26).
#   R4 rewind saga (t43-t45): T43 -> T44 -> T45 is a fixed state chain
#      (marker + isolated node hand-off), no reordering possible.
#   R5 creation matrix (t46-t53): every case fetches its own pending
#      nonce, so the eight cases are mutually independent.
SCHEDULE=(
    t01 t03 t11 t12 t13 t16 t17 t20 t02 t04 t05 t06 t08 t15 t14 t18 t19 t21 t22 t09 t10 t07 t23 t24 t26 t27 t29 t33 t28 t25 t30 t31 t32 t34 t35 t36 t37 t38 t39 t41 t42 t40 t43 t44 t45 t47 t48 t51 t49 t50 t52 t53 t46
)

# per-case wall-time expectation (seconds) for the test line's expected=<n>s:
# the ceil of the last full run's verdict elapsed= value, minimum 1 (0.0s and
# 0.1s both map to 1). Source run: results/gas2500x-20260905-101010.log.
# Regenerate after timing-changing edits.
declare -A EXPECTED=(
    # ceil of run #26's verdict elapsed values (0.0s and 0.1s map to 1).
    # Source run: results/gas2500x-20260905-122923.log (2026-09-05).
    # Regenerate after timing-changing edits. [t01] measured 1.4s after the
    # async-batch funding rewrite (one block instead of six serial waits).
    # [t23]/[t50] recalibrated from run 27 (20260905-151141, 53/0/0 green).
    [t01]=2 [t02]=3 [t03]=1 [t04]=65 [t05]=1 [t06]=1 [t07]=21 [t08]=1 [t09]=13
    [t10]=1 [t11]=1 [t12]=1 [t13]=1 [t14]=2 [t15]=1 [t16]=1 [t17]=1 [t18]=2
    [t19]=2 [t20]=1 [t21]=2 [t22]=2 [t23]=93 [t24]=1 [t25]=3 [t26]=1 [t27]=1
    [t28]=2 [t29]=1 [t30]=130 [t31]=1 [t32]=13 [t33]=1 [t34]=130 [t35]=1 [t36]=1
    [t37]=1 [t38]=1 [t39]=1 [t40]=2 [t41]=1 [t42]=1 [t43]=12 [t44]=62 [t45]=68
    [t46]=3 [t47]=1 [t48]=1 [t49]=2 [t50]=1 [t51]=1 [t52]=2 [t53]=2
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
    # strip the leading zero FIRST: printf 'T%02d' treats 08/09 as invalid
    # octal literals (seen as "printf: 08: invalid octal number" in run 24)
    id_num=${item%%-*}; id_num=${id_num#t}
    id_num=${id_num#0}
    case_id=$(printf 'T%02d' "$id_num")
    # per-case wall-time expectation printed on the test line (ceil of the
    # last full run's elapsed, minimum 1 — see the EXPECTED table)
    export EXPECTED_S="${EXPECTED[$item]:-1}"
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
