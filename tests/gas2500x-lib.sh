#!/bin/bash
# gas2500x-lib.sh — shared helpers for the gas2500x t*.sh case scripts.
#
# Sourcing contract: every t*.sh starts with
#     source "$(dirname "$0")/gas2500x-lib.sh"
# (the lib cds to the setup root itself, so all relative paths — nodes/,
# logs/, .env — resolve there), calls begin_case, and ends with exactly one
# pass_case/fail_case/skip_case.
#
# Environment:
#   .env in the repo root provides PRIVATE_KEY_0 (pn0 prefunded signer),
#   PRIVATE_KEY_3 (pn3's own key) and TXGEN_KEY_1/2/3/4 (raw sender keys
#   S1/S2/S3/S4).
# Requirements: bash, curl, jq, cast (foundry).
#
# Results: one "T02: pass number=<head> result=<evidence>" verdict line per
# case on stdout (the runner stamps and tees these into
# results/gas2500x-<ts>.log).
# No results .md file is created unless the caller exports RESULTS_FILE
# themselves (opt-in for standalone debugging).

set -o pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT" || exit

# every target in this harness (RPC, metrics, cast sends) is loopback — never
# route curl/cast through a proxy even when the environment exports
# http_proxy/https_proxy (both curl and cast honor no_proxy/NO_PROXY)
export no_proxy='127.0.0.1,localhost'
export NO_PROXY="$no_proxy"

[ -f .env ] && set -a && . ./.env && set +a

RPC0="http://127.0.0.1:8545"          # pn0 (masternode, prefunded signer)
RPC3="http://127.0.0.1:8548"          # pn3 (observer, pool under test)

CHAIN_ID="${CHAIN_ID:-5151}"
FORK_BLOCK="${FORK_BLOCK:-120}"
# tier prices in wei — consumed by the case scripts that source this lib
# shellcheck disable=SC2034
GAS50_WEI=12500000000                 # 12.5 gwei
# shellcheck disable=SC2034
GAS2500_WEI=625000000000              # 625 gwei
RESULTS_FILE="${RESULTS_FILE:-}"

if [ -n "$RESULTS_FILE" ]; then
    mkdir -p "$(dirname "$RESULTS_FILE")"
    # table header on first creation, so the file is standalone-readable
    if [ ! -s "$RESULTS_FILE" ]; then
        printf '| Case | Status | Block | Name | Evidence |\n|---|---|---|---|---|\n' \
            >"$RESULTS_FILE"
    fi
fi

# ------------------------------------------------------------------ rpc utils
rpc() { # <node-url> <method> [params-json-array]
    local url=$1 method=$2 params=${3:-[]}
    curl -s -m 5 -X POST -H 'Content-Type: application/json' \
        --data "{\"jsonrpc\":\"2.0\",\"id\":1,\"method\":\"$method\",\"params\":$params}" \
        "$url"
}

# rpc0 <method> [params...] — raw JSON text params, prints .result
rpc0() {
    local method=$1 params=${2:-[]}
    rpc "$RPC0" "$method" "$params" | jq -c '.result'
}

# rpc3 <method> [params...] — same against pn3
rpc3() {
    local method=$1 params=${2:-[]}
    rpc "$RPC3" "$method" "$params" | jq -c '.result'
}

hex2dec() { printf '%d' "$1" 2>/dev/null; }

# head3/head0: current head; prints -1 when the RPC is unreachable. (A bare
# hex2dec of an empty RPC reply would print 0 and mask node-down as head 0.)
head3() { local h; h=$(rpc3 eth_blockNumber | jq -r .); case "$h" in 0x*) hex2dec "$h";; *) echo -1;; esac; }
head0() { local h; h=$(rpc0 eth_blockNumber | jq -r .); case "$h" in 0x*) hex2dec "$h";; *) echo -1;; esac; }

# txpool counters of pn3: prints "<pending> <queued>"
pool3() {
    local r
    r=$(rpc3 txpool_status)
    printf '%d %d\n' \
        "$(hex2dec "$(printf '%s' "$r" | jq -r .pending)")" \
        "$(hex2dec "$(printf '%s' "$r" | jq -r .queued)")"
}

# wait_head <target> [timeout-s] — block until pn3 head >= target
wait_head() {
    local target=$1 timeout=${2:-120} t=0 head
    while :; do
        head=$(head3)
        [ "$head" -ge "$target" ] && return 0
        [ "$t" -ge "$timeout" ] && return 1
        sleep 2
        t=$((t + 2))
    done
}

# pending_regular — pn3's pending count excluding XDPoS CONSENSUS SIGNING
# txs. Every ~30 s each masternode broadcasts one (to = the 0x…0089 system
# contract, gasPrice = 0); sent by a genesis signer it enters every node's
# pool as an executable-special entry (promoteSpecialTx — no "Pooled" trace)
# and is removed ~2 s later when the block carrying it imports, so a raw
# pending read can transiently show up to 3. User txs cannot match the
# filter: gasPrice 0 is rejected at admission (ErrZeroGasPrice), and nothing
# else in the pool targets the system contract.
# NB: txpool_content keys are XDC-PREFIXED ("xdc77cb…"), while the tx
# objects' own from/to fields are 0x-prefixed — never match on the keys.
pending_regular() {
    rpc3 txpool_content | jq -r '
        [((.pending // {}) | to_entries[]) | .value[]
         | select((((.to // "") | ascii_downcase)
                   != "0x0000000000000000000000000000000000000089")
              or ((.gasPrice // "0x0") != "0x0"))] | length'
}

# wait_rpc3 [timeout-s] — block until pn3's RPC answers eth_blockNumber
# (head3 prints -1 while the node is down)
wait_rpc3() {
    local timeout=${1:-30} t=0 head
    while :; do
        head=$(head3)
        [ "$head" != "-1" ] && [ -n "$head" ] && return 0
        [ "$t" -ge "$timeout" ] && return 1
        sleep 1
        t=$((t + 1))
    done
}

# --------------------------------------------------------------- tx utilities
addr_of() { # <key-env-name> — derive the address of a raw key from .env
    cast wallet address --private-key "$(printenv "$1")" 2>/dev/null
}

# _cast_send <url> <key-env-name> <to> <value-wei> [gasprice-wei] [nonce]
#            [extra cast args...]
# The one place that builds a cast send: a locally signed tx, legacy by
# default. --legacy is REQUIRED for the legacy cases: cast silently upgrades
# to EIP-1559 on London+ chains (fee cap = --gas-price, tip = 1 wei), and a
# same-nonce replacement then fails the "tip must strictly increase" gate no
# matter how much the fee cap rises. Legacy txs put the whole bump into
# gasPrice (= tipCap = feeCap). An empty gas price omits the flag — the node
# then signs at the tier-aware default price (t13).
# The EIP-1559 cases (t32/t33) pass --priority-gas-price in the extras; cast
# then treats the gas-price positional as the max fee per gas, and the two
# flavors are mutually exclusive, so those skip --legacy instead.
_cast_send() {
    local url=$1 keyvar=$2 to=$3 value=$4 gp=${5:-} nonce=${6:-}
    shift 6
    # NB: not plain "args" — the runner has a scalar args and shellcheck -x
    # merges scopes across the sourced lib
    local cast_args=(
        send "$to" --value "$value"wei --gas-limit 21000
        --private-key "$(printenv "$keyvar")" --rpc-url "$url"
        --chain-id "$CHAIN_ID" --json
    )
    local extra dynamic=1
    for extra in "$@"; do
        case $extra in
        --priority-gas-price) dynamic= ;;
        esac
    done
    [ -n "$dynamic" ] && cast_args+=(--legacy)
    cast_args+=("$@")
    [ -n "$gp" ] && cast_args+=(--gas-price "$gp"wei)
    [ -n "$nonce" ] && cast_args+=(--nonce "$nonce")
    cast "${cast_args[@]}"
}

# send_from <key-env-name> <to> <value-wei> <gasprice-wei> [nonce]
#            [extra cast args...]
# Signs locally with cast and submits via pn3's RPC. Prints the tx hash on
# success; on RPC rejection prints the error text to stderr and returns 1.
# The send is async (--async): cast broadcasts and exits immediately instead
# of waiting for a receipt — queued (nonce-gap) txs never seal, so a receipt
# wait would stall every pool-seeding submission for its full timeout.
send_from() {
    local keyvar=$1 to=$2 value=$3 gp=$4 nonce=${5:-}
    # optional tail: extra cast args (the EIP-1559 tip flag of t32)
    local extras=()
    if [ "$#" -gt 5 ]; then shift 5; extras=("$@"); fi
    # per-process error file: parallel case runs must not clobber each other
    local err="/tmp/g2500-send-$$" out
    out=$(_cast_send "$RPC3" "$keyvar" "$to" "$value" "$gp" "$nonce" --async \
        ${extras[@]+"${extras[@]}"} 2>"$err")
    # --async --json prints the bare hash on success, an error JSON on failure
    if printf '%s' "$out" | grep -qE '^0x[0-9a-fA-F]{64}$'; then
        printf '%s\n' "$out"
        return 0
    fi
    printf '%s' "$out" | jq -r '.errors[0].message? // empty' 2>/dev/null >&2
    grep -m1 . "$err" >&2 2>/dev/null || true
    return 1
}

# expect_reject <key-env-name> <to> <value-wei> <gasprice-wei> <needle>
#               [nonce] [extra cast args...]
# Assert the send is rejected with an error containing <needle>; prints the
# error otherwise.
expect_reject() {
    local keyvar=$1 to=$2 value=$3 gp=$4 needle=$5 nonce=${6:-}
    # optional tail: extra cast args (the EIP-1559 tip flag of t33)
    local extras=()
    if [ "$#" -gt 6 ]; then shift 6; extras=("$@"); fi
    # capture BOTH streams: cast --json prints its error JSON on stdout;
    # --async keeps the accepted path from stalling on a receipt wait
    out=$(_cast_send "$RPC3" "$keyvar" "$to" "$value" "$gp" "$nonce" --async \
        ${extras[@]+"${extras[@]}"} 2>&1) || true
    printf '%s' "$out" | grep -qi "$needle" && return 0
    printf '%s' "$out" >&2
    return 1
}

# ------------------------------------------------- contract-creation sends
# _cast_create <key-env> <mode> <gp> <code> [nonce] — creation twin of
# _cast_send for T35. <mode> picks the tx shape:
#   legacy — --legacy --gas-price <gp>        (gasPrice = gp)
#   maxfee — --gas-price <gp>, no --legacy    (gasPrice doubles as GasFeeCap,
#            tip = cast's default 1 wei)
#   tip    — --priority-gas-price 0           (tip = 0, fee cap = cast's
#            estimate; seals at the base fee)
# Prints cast's --json output with stderr merged: a bare hash when accepted,
# an error JSON when rejected. The 60000 gas allowance covers the minimal
# runtime (~53k estimate).
_cast_create() {
    local keyvar=$1 mode=$2 gp=$3 code=$4 nonce=${5:-}
    local cast_args=(
        send --create "$code" --value 0wei --gas-limit 60000
        --private-key "$(printenv "$keyvar")" --rpc-url "$RPC3"
        --chain-id "$CHAIN_ID" --json --async
    )
    case $mode in
    legacy) cast_args+=(--legacy --gas-price "$gp"wei) ;;
    maxfee) cast_args+=(--gas-price "$gp"wei) ;;
    tip)    cast_args+=(--priority-gas-price 0) ;;
    *)      echo "cast_create: bad mode $mode" >&2; return 2 ;;
    esac
    [ -n "$nonce" ] && cast_args+=(--nonce "$nonce")
    cast "${cast_args[@]}" 2>&1
}

# create_from <key-env> <mode> <gp> <code> [nonce] — accepted path of
# _cast_create: prints the bare tx hash, rc 1 (error text on stderr) when
# rejected.
create_from() {
    local out
    out=$(_cast_create "$@") || { printf '%s' "$out" >&2; return 1; }
    if printf '%s' "$out" | grep -qE '^0x[0-9a-fA-F]{64}$'; then
        printf '%s\n' "$out"
        return 0
    fi
    printf '%s' "$out" | jq -r '.errors[0].message? // empty' 2>/dev/null >&2
    printf '%s' "$out" >&2
    return 1
}

# expect_create_reject <key-env> <mode> <gp> <code> <needle> [nonce]
# Assert the creation tx is rejected with an error containing <needle>.
expect_create_reject() {
    local keyvar=$1 mode=$2 gp=$3 code=$4 needle=$5 nonce=${6:-}
    local out
    out=$(_cast_create "$keyvar" "$mode" "$gp" "$code" "$nonce") || true
    printf '%s' "$out" | grep -qi "$needle" && return 0
    printf '%s' "$out" >&2
    return 1
}

# receipt_field <hash> <field> [timeout-s]
receipt_field() {
    local hash=$1 field=$2 timeout=${3:-30} t=0 r v
    [ -n "$hash" ] && [ "$hash" != "null" ] || return 1
    while :; do
        r=$(rpc3 eth_getTransactionReceipt "[\"$hash\"]")
        v=$(printf '%s' "$r" | jq -r ".$field // empty")
        [ -n "$v" ] && { echo "$v"; return 0; }
        [ "$t" -ge "$timeout" ] && return 1
        sleep 1
        t=$((t + 1))
    done
}

# ----------------------------------------------------- chain/state inspection
# content_from <addr> — pn3's txpool_contentFrom for one sender. Returns
# {pending|queued: {nonce: tx}} — a SINGLE-level map per group (flattenTxs
# keys by nonce), so '..' safely walks the tx objects.
content_from() { rpc3 txpool_contentFrom "[\"$1\"]"; }

# pool_hashes_from <addr> — hashes of every tx the pool holds for <addr>
pool_hashes_from() { content_from "$1" | jq -r '.. | .hash? // empty'; }

# pool_txs_from <addr> — how many txs the pool holds for <addr>
pool_txs_from() { content_from "$1" | jq '[.. | .hash? // empty | select(length>0)] | length'; }

# pending_nonce <addr> — the account's pending transaction count (decimal)
pending_nonce() {
    hex2dec "$(rpc3 eth_getTransactionCount "[\"$1\", \"pending\"]" | jq -r .)"
}

# base_fee <number|latest> — a block's baseFeePerGas in wei (decimal)
base_fee() {
    hex2dec "$(rpc3 eth_getBlockByNumber "[\"$1\", false]" | jq -r .baseFeePerGas)"
}

# ------------------------------------------------------------ node lifecycle
# wait_port_free <port> [timeout-s] — block until the local port refuses
# connections (the previous owner died); else return 1. Without this a fast
# stop/start sequence hands the new node a socket whose old owner is still
# shutting down, and reads land on the wrong (dying) process.
wait_port_free() {
    local port=$1 timeout=${2:-20} t=0
    while :; do
        curl -s --noproxy '*' -m 1 "http://127.0.0.1:$port" >/dev/null 2>&1 || return 0
        [ "$t" -ge "$timeout" ] && return 1
        sleep 1
        t=$((t + 1))
    done
}

# stop_pn3 [metrics-timeout-s] — kill the regular pn3 and wait until its RPC
# (8548) and metrics (6063) ports refuse connections. Shared by every pn3
# restart so back-to-back restarts never read a dying process's socket.
stop_pn3() {
    local met_timeout=${1:-5}
    ./stop-network.sh 3 >/dev/null 2>&1
    pkill -f 'XDC --config nodes/pn3' 2>/dev/null
    wait_port_free 8548 20 || true
    wait_port_free 6063 "$met_timeout" || true
}

# restart_pn3 — stop/start the regular (peered) pn3 and wait for its RPC.
# Returns 1 if the node failed to start or its RPC stayed down; callers
# decide whether that is fatal.
restart_pn3() {
    stop_pn3
    ./run-node.sh 3 >/dev/null 2>&1 || return 1
    wait_rpc3 30
}

# pn0_enode — pn0's enode URL from its admin_nodeInfo
pn0_enode() { rpc0 admin_nodeInfo | jq -r .enode; }

# restore_pn3 — bring the regular (peered) pn3 back after the isolated
# experiment (t29): kill whatever is on 8548, put the real config back,
# start. Shared by t29/t30 so every failure path still leaves a sane node.
restore_pn3() {
    stop_pn3 10
    [ -f nodes/pn3/XDC/config.toml.bak ] &&
        mv nodes/pn3/XDC/config.toml.bak nodes/pn3/XDC/config.toml 2>/dev/null
    ./run-node.sh 3 >/dev/null 2>&1
}

# ------------------------------------------------------------- observability
# meter_port <port> <name> — last value of a counter on a node's prometheus
# endpoint (metrics ports: pn0-pn3 = 6060-6063)
meter_port() {
    curl -s "http://127.0.0.1:$1/debug/metrics/prometheus" |
        grep "^$2" | tail -n 1 | awk '{print $2}'
}

# meter3 <name> — read a counter from pn3's prometheus endpoint (last value)
meter3() { meter_port 6063 "$1"; }

# gauge3 <name> — meter3 with 0 for a missing counter (an absent counter
# reads as zero; callers compare numbers, not emptiness)
gauge3() {
    local v
    v=$(meter3 "$1")
    echo "${v:-0}"
}

# journal_size — byte size of pn3's local tracker journal
journal_size() { stat -c %s "$ROOT/nodes/pn3/XDC/transactions.rlp" 2>/dev/null || echo 0; }

# -------------------------------------------------------- fork window guards
# require_pre_fork [why] — skip the case unless the head is still below the
# fork (a pre-fork case run after the fork has missed its window)
require_pre_fork() {
    local h why=${1:-run before the fork}
    h=$(head3)
    [ "$h" -lt "$FORK_BLOCK" ] || skip_case "head $h >= fork $FORK_BLOCK; $why"
}

# require_post_fork — fail unless the head is past the fork
require_post_fork() {
    local h
    h=$(head3)
    [ "$h" -ge "$FORK_BLOCK" ] || fail_case "head $h < fork $FORK_BLOCK"
}

# fork_side <pre|post> — guard for the two-sided cases (t10-t15): a pre run
# past the fork skips, anything but pre|post is a usage failure
fork_side() {
    case "$1" in
    pre)  require_pre_fork "pre side missed the window" ;;
    post) ;;
    *)    fail_case "usage: ${0##*/} pre|post" ;;
    esac
}

# tier_for <pre|post> — the enforced floor price (wei) on that side of the
# fork; callers have already run fork_side, so the side is valid here
tier_for() {
    if [ "$1" = "pre" ]; then echo "$GAS50_WEI"; else echo "$GAS2500_WEI"; fi
}

# ----------------------------------------------------------------- case frame
CASE_ID="" CASE_NAME="" CASE_T0=0

# result_block — pn3's head at verdict time (-1 while the node is down);
# used by the verdict line and the opt-in results-file rows
result_block() { head3; }

case_result() { # <id> <pass|fail|skip> <name> <evidence>
    local id=$1 status=$2 name=$3 evidence=$4
    evidence=$(printf '%s' "$evidence" | tr '\n' ' ')
    # verdict line goes to stdout (the runner's transcript aggregates these);
    # the status word is lowercase everywhere — on the verdict line and in
    # the opt-in results-file row. number is the chain head at verdict time
    # (the test line's number is the head at case start); elapsed is the
    # case's own wall time to 0.1 s, measured from begin_case.
    local elapsed_ms=$(( $(date +%s%3N) - CASE_T0 ))
    local elapsed="$((elapsed_ms / 1000)).$(( (elapsed_ms % 1000) / 100 ))s"
    printf '%s: %s number=%s elapsed=%s result=%s\n' \
        "$id" "$status" "$(result_block)" "$elapsed" "$evidence"
    if [ -n "$RESULTS_FILE" ]; then
        printf '| %s | %s | %s | %s | %s |\n' \
            "$id" "$status" "$(result_block)" "$name" \
            "$(printf '%s' "$evidence" | sed 's/|/\\|/g')" \
            >>"$RESULTS_FILE"
    fi
}

begin_case() { # <id> <name>
    CASE_ID=$1
    CASE_NAME=${2:-$1}
    # start the elapsed clock first thing; the test line carries the chain
    # head at the moment the case starts, so transcript rows can be
    # correlated with blocks, plus the case name for grep-ability (the
    # verdict line only carries evidence)
    CASE_T0=$(date +%s%3N)
    printf '%s: test number=%s expected=%ss name=%s\n' \
        "$CASE_ID" "$(head3)" "${EXPECTED_S:-1}" "$CASE_NAME"
}

pass_case() { # [evidence]
    case_result "$CASE_ID" pass "$CASE_NAME" "${1:-ok}"
    exit 0
}

fail_case() { # [evidence]
    case_result "$CASE_ID" fail "$CASE_NAME" "${1:-failed}"
    exit 1
}

# skip_case: the case's precondition is not met on the current chain (e.g. a
# pre-fork case run after the fork) — neither a failure nor a pass.
skip_case() { # [evidence]
    case_result "$CASE_ID" skip "$CASE_NAME" "${1:-precondition not met}"
    exit 0
}
