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

# "<script>-<side>" entries run tests/<script>.sh with the side as its
# argument. Ordering constraints: t34-pre parks the sweep survivor (t17
# asserts it), t34-post seals it right after t17 so t30 re-imports the
# seal blocks before its poll, and t32/t33 run after the t29-t31 saga so
# their txs are never in the journal at the rewind.
SCHEDULE=(
    t1 t2 t3 t4 t5 t6 t7 t8 t9 t34-pre
    t10-pre t11-pre t12-pre t13-pre t14-pre t15-pre
    t16 t17 t34-post t18 t19
    t20 t21 t22 t23 t24 t25 t26 t27 t28
    t10-post t11-post t12-post t13-post t14-post t15-post
    t29 t30 t31
    t32 t33
)

# per-case wall-time expectation (seconds) for the test line's expected=<n>s:
# the ceil of the last full run's verdict elapsed= value, minimum 1 (0.0s and
# 0.1s both map to 1). Source run: results/gas2500x-20260905-101010.log.
# Regenerate after timing-changing edits.
declare -A EXPECTED=(
    [t1]=9 [t2]=3 [t3]=1 [t4]=65 [t5]=1 [t6]=1 [t7]=21 [t8]=1 [t9]=13
    [t34-pre]=1
    [t10-pre]=1 [t11-pre]=1 [t12-pre]=1 [t13-pre]=2 [t14-pre]=1 [t15-pre]=1
    [t16]=107 [t17]=1 [t34-post]=3 [t18]=1 [t19]=1
    [t20]=2 [t21]=1 [t22]=130 [t23]=1 [t24]=13 [t25]=1 [t26]=130 [t27]=1 [t28]=1
    [t10-post]=1 [t11-post]=1 [t12-post]=1 [t13-post]=2 [t14-post]=1 [t15-post]=1
    [t29]=12 [t30]=62 [t31]=68
    [t32]=3 [t33]=1
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
    # T29 disarms the gate once (see below); missing scripts skip above
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
    id_num=${item%%-*}; id_num=${id_num#t}
    case_id=$(printf 'T%02d' "$id_num")
    # per-case wall-time expectation printed on the test line (ceil of the
    # last full run's elapsed, minimum 1 — see the EXPECTED table)
    export EXPECTED_S="${EXPECTED[$item]:-1}"
    # the verdict search only sees lines this case produced (twice-cases)
    mark=$(wc -l <"$LOG" 2>/dev/null || echo 0)
    bash "$f" "$args"
    # poll briefly: the verdict lands in $LOG asynchronously
    verdict=""
    for _ in $(seq 1 15); do
        verdict=$(tail -n +"$((mark + 1))" "$LOG" 2>/dev/null |
            grep -E " $case_id: (pass|fail|skip)" | tail -n 1)
        [ -n "$verdict" ] && break
        sleep 0.2
    done
    # T29 rewinds the chain (--set-head 30), so its number= can never be
    # advanced past — disarm the gate once for T30.
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

# stop the network when the run is done
./stop-network.sh >/dev/null 2>&1 || true
./stop-rpc.sh >/dev/null 2>&1 || true

# last line of the log
echo "end: pass=$passed fail=$failed skip=$skipped"

[ "$failed" = "0" ] || exit 1
