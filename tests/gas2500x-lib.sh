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
# Result file: one markdown table row per case:
#   markdown table row | T2 | PASS | 90 | name | evidence |
# gas2500x-run.sh pre-sets RESULTS_FILE to a per-run timestamped file so
# earlier runs are never overwritten; standalone case runs append to the
# shared results/gas2500x-results.md.

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
RESULTS_DIR="$ROOT/results"
# keep a caller-provided RESULTS_FILE (gas2500x-run.sh sets a per-run file
# and exports it); standalone case runs fall back to the shared default
RESULTS_FILE="${RESULTS_FILE:-$RESULTS_DIR/gas2500x-results.md}"

# ---------------------------------------------------------------- result file
mkdir -p "$RESULTS_DIR"

# Table header is written when the results file is created, never per row.
# gas2500x-run.sh pre-creates the per-run file with the header before the
# case scripts run; this fallback only fires for a standalone case run that
# starts a fresh default results file.
if [ ! -s "$RESULTS_FILE" ]; then
    printf '| Case | Status | Block | Name | Evidence |\n|---|---|---|---|---|\n' \
        >"$RESULTS_FILE"
fi

# result_block: the pn3 head at the moment the verdict is written — the block
# number replaces the wall-clock timestamp so results are chain-orderable.
# Fallback: -1 when the node is unreachable (e.g. a case that killed pn3).
result_block() {
    local bn
    bn=$(curl -s -X POST -H 'Content-Type: application/json' \
        --data '{"jsonrpc":"2.0","id":1,"method":"eth_blockNumber","params":[]}' \
        "$RPC3" | jq -r '.result // empty' 2>/dev/null)
    [ -n "$bn" ] && printf '%d' "$bn" 2>/dev/null || echo -1
}

case_result() { # <id> <PASS|FAIL|SKIP> <name> <evidence>
    local id=$1 status=$2 name=$3 evidence=$4
    # markdown table row; the table header is the runner's job
    # (gas2500x-run.sh) and is written when the file is created
    printf '| %s | %s | %s | %s | %s |\n' \
        "$id" "$status" "$(result_block)" "$name" \
        "$(printf '%s' "$evidence" | sed 's/|/\\|/g' | tr '\n' ' ')" \
        >>"$RESULTS_FILE"
    printf '%s %s (block %s) — %s\n' "$id" "$status" "$(result_block)" "$evidence"
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

head3() { hex2dec "$(rpc3 eth_blockNumber | jq -r .)"; }
head0() { hex2dec "$(rpc0 eth_blockNumber | jq -r .)"; }

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
send_from() {
    local keyvar=$1 to=$2 value=$3 gp=$4 nonce=${5:-}
    local nonce_args=()
    [ -n "$nonce" ] && nonce_args=(--nonce "$nonce")
    cast send "$to" --value "$value"wei --gas-price "$gp"wei --gas-limit 21000 \
        --private-key "$(printenv "$keyvar")" --rpc-url "$RPC3" \
        --chain-id "$CHAIN_ID" --json "${nonce_args[@]}" 2>/tmp/g2500-send-err |
        jq -r .transactionHash
}

# expect_reject <keyvar> <to> <value> <gasprice> <needle> — assert the send is
# rejected with an error containing <needle>; prints the error.
expect_reject() {
    local keyvar=$1 to=$2 value=$3 gp=$4 needle=$5 out
    out=$(cast send "$to" --value "$value"wei --gas-price "$gp"wei \
        --gas-limit 21000 --private-key "$(printenv "$keyvar")" \
        --rpc-url "$RPC3" --chain-id "$CHAIN_ID" --json 2>&1 >/dev/null) || true
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

# meter3 <name> — read a counter from pn3's prometheus endpoint (last value)
meter3() { curl -s "$MET3/debug/metrics/prometheus" | grep "^$1" | tail -n 1 | awk '{print $2}'; }

# journal_size — byte size of pn3's local tracker journal
journal_size() { stat -c %s "$ROOT/nodes/pn3/XDC/transactions.rlp" 2>/dev/null || echo 0; }

# ----------------------------------------------------------------- case frame
CASE_ID="" CASE_NAME=""

begin_case() { # <id> <name>
    CASE_ID=$1
    CASE_NAME=${2:-$1}
    printf '%s: running (%s)\n' "$CASE_ID" "$CASE_NAME"
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
