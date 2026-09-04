#!/bin/bash
# gas2500x-lib.sh — shared helpers for the gas2500x T*.sh case scripts.
#
# Sourcing contract: every T*.sh does
#     cd "$(dirname "$0")/.." ; source tests/gas2500x-lib.sh
# then defines its checks and calls run_case at the end.
#
# Environment:
#   .env in the repo root provides PRIVATE_KEY_0 (pn0 prefunded signer)
#   and TXGEN_KEY_1/2/3 (raw sender keys S1/S2/S3).
# Requirements: bash, curl, jq, cast (foundry).
#
# Results: printed to stdout — one "T02: PASS - evidence" line per case
# case verdict. No results file is created unless the caller exports
# RESULTS_FILE themselves (opt-in for standalone debugging).

set -o pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT" || exit

[ -f .env ] && set -a && . ./.env && set +a

RPC0="http://127.0.0.1:8545"          # pn0 (masternode, prefunded signer)
RPC3="http://127.0.0.1:8548"          # pn3 (observer, pool under test)
MET3="http://127.0.0.1:6063"          # pn3 metrics

CHAIN_ID="${CHAIN_ID:-5151}"
FORK_BLOCK="${FORK_BLOCK:-90}"
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

case_result() { # <id> <PASS|FAIL|SKIP> <name> <evidence>
    local id=$1 status=$2 name=$3 evidence=$4
    evidence=$(printf '%s' "$evidence" | tr '\n' ' ')
    # verdict line goes to stdout (the runner aggregates these into its table);
    # same "T1: ..." shape as begin_case's running line, no block number
    printf '%s: %s - %s\n' "$id" "$status" "$evidence"
    if [ -n "$RESULTS_FILE" ]; then
        printf '| %s | %s | %s | %s | %s |\n' \
            "$id" "$status" "$(result_block)" "$name" \
            "$(printf '%s' "$evidence" | sed 's/|/\\|/g')" \
            >>"$RESULTS_FILE"
    fi
}

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

# wait_floor_change <old-floor> [timeout-s] — wait until gasPrice leaves old
wait_floor_change() {
    local old=$1 timeout=${2:-90} t=0 gp
    while :; do
        gp=$(hex2dec "$(rpc0 eth_gasPrice | jq -r .)")
        [ "$gp" != "$old" ] && { echo "$gp"; return 0; }
        [ "$t" -ge "$timeout" ] && return 1
        sleep 2
        t=$((t + 2))
    done
}

# --------------------------------------------------------------- tx utilities
addr_of() { # <key-env-name> — derive the address of a raw key from .env
    cast wallet address --private-key "$(printenv "$1")" 2>/dev/null
}

# send_from <key-env-name> <to> <value-wei> <gasprice-wei> [nonce]
# Signs locally with cast and submits via pn3's RPC. Prints the tx hash on
# success; on RPC rejection prints the error text to stderr and returns 1.
# The send is async (--async): cast broadcasts and exits immediately instead
# of waiting for a receipt — queued (nonce-gap) txs never seal, so a receipt
# wait would stall every pool-seeding submission for its full timeout.
# --legacy is REQUIRED: cast silently upgrades to EIP-1559 on London+ chains
# (fee cap = --gas-price, tip = 1 wei), and a same-nonce replacement then
# fails the "tip must strictly increase" gate no matter how much the fee cap
# rises. Legacy txs put the whole bump into gasPrice (= tipCap = feeCap).
send_from() {
    local keyvar=$1 to=$2 value=$3 gp=$4 nonce=${5:-}
    local nonce_args=() out
    [ -n "$nonce" ] && nonce_args=(--nonce "$nonce")
    out=$(cast send "$to" --value "$value"wei --gas-price "$gp"wei \
        --gas-limit 21000 --private-key "$(printenv "$keyvar")" \
        --rpc-url "$RPC3" --chain-id "$CHAIN_ID" --json --async --legacy \
        "${nonce_args[@]}" 2>/tmp/g2500-send-err)
    # --async --json prints the bare hash on success, an error JSON on failure
    if printf '%s' "$out" | grep -qE '^0x[0-9a-fA-F]{64}$'; then
        printf '%s\n' "$out"
        return 0
    fi
    printf '%s' "$out" | jq -r '.errors[0].message? // empty' 2>/dev/null >&2
    grep -m1 . /tmp/g2500-send-err >&2 2>/dev/null || true
    return 1
}

# expect_reject <keyvar> <to> <value> <gasprice> <needle> — assert the send is
# rejected with an error containing <needle>; prints the error.
expect_reject() {
    local keyvar=$1 to=$2 value=$3 gp=$4 needle=$5 out
    # capture BOTH streams: cast --json prints its error JSON on stdout;
    # --async keeps the accepted path from stalling on a receipt wait
    out=$(cast send "$to" --value "$value"wei --gas-price "$gp"wei \
        --gas-limit 21000 --private-key "$(printenv "$keyvar")" \
        --rpc-url "$RPC3" --chain-id "$CHAIN_ID" --json --async --legacy 2>&1) || true
    printf '%s' "$out" | grep -qi "$needle" && return 0
    printf '%s' "$out" >&2
    return 1
}

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

# pn0_enode — pn0's enode URL from its admin_nodeInfo
pn0_enode() { rpc0 admin_nodeInfo | jq -r .enode; }

# restore_pn3 — bring the regular (peered) pn3 back after the isolated
# experiment: kill whatever is on 8548, put the real config back, start.
# Shared by t29/t30 so every failure path still leaves a sane node behind.
restore_pn3() {
    ./stop-network.sh 3 >/dev/null 2>&1
    pkill -f 'XDC --config nodes/pn3' 2>/dev/null
    wait_port_free 8548 20
    wait_port_free 6063 5
    [ -f nodes/pn3/XDC/config.toml.bak ] &&
        mv nodes/pn3/XDC/config.toml.bak nodes/pn3/XDC/config.toml 2>/dev/null
    ./run-node.sh 3 >/dev/null 2>&1
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

# meter3 <name> — read a counter from pn3's prometheus endpoint (last value)
meter3() { curl -s "$MET3/debug/metrics/prometheus" | grep "^$1" | tail -n 1 | awk '{print $2}'; }

# journal_size — byte size of pn3's local tracker journal
journal_size() { stat -c %s "$ROOT/nodes/pn3/XDC/transactions.rlp" 2>/dev/null || echo 0; }

# ----------------------------------------------------------------- case frame
CASE_ID="" CASE_NAME=""

begin_case() { # <id> <name>
    CASE_ID=$1
    CASE_NAME=${2:-$1}
    printf '%s: running - %s\n' "$CASE_ID" "$CASE_NAME"
}

pass_case() { # [evidence]
    case_result "$CASE_ID" PASS "$CASE_NAME" "${1:-ok}"
    exit 0
}

fail_case() { # [evidence]
    case_result "$CASE_ID" FAIL "$CASE_NAME" "${1:-failed}"
    exit 1
}

# skip_case: the case's precondition is not met on the current chain (e.g. a
# pre-fork case run after the fork) — neither a failure nor a pass.
skip_case() { # [evidence]
    case_result "$CASE_ID" SKIP "$CASE_NAME" "${1:-precondition not met}"
    exit 0
}
