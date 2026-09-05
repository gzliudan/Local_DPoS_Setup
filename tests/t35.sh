#!/bin/bash
# T35 — contract-creation pricing around the tier floor (twice-case).
# Usage: t35.sh pre|post
#
# Six creation txs probe the admission floor from both sides, on both tiers
# (pre-fork floor 12.5 gwei, post-fork floor 625 gwei) — the forge-create
# matrix the issue reporter used, expressed with cast:
#   tx1  legacy, floor-1    -> rejected at once (under min gas price)
#   tx2  legacy, floor      -> sealed at the floor
#   tx3  legacy, floor+1    -> sealed at floor+1
#   tx4  1559 fee cap floor-1 -> rejected at once (floor compares GasFeeCap)
#   tx5  1559 fee cap floor -> sealed at the floor
#   tx6  1559, tip 0        -> sealed at the base fee
# All six go from S5 (funded in T01) via pn3's RPC. The two rejects are
# never tracked (#2541/#2547); the four seals leave the journal "ok" and do
# not perturb the hold-back arithmetic of T18/T19/T22/T26/T29-T31.
source "$(dirname "$0")/gas2500x-lib.sh"
begin_case "T35" "creation txs priced around the tier floor (${1:-?} side)"

side=${1:-pre}
fork_side "$side"

# minimal deployable bytecode: PUSH1 0 PUSH1 0 RETURN — an empty runtime
code=0x60006000f3

floor=$(tier_for "$side")
below=$((floor - 1))
above=$((floor + 1))

s5=$(addr_of TXGEN_KEY_5)
n=$(pending_nonce "$s5")

# tx1 + tx4: the two below-floor shapes must fail at once, before the pool
if ! expect_create_reject TXGEN_KEY_5 legacy "$below" "$code" \
    "under min gas price" "$n"; then
    fail_case "tx1 (legacy $below) was not rejected"
fi
if ! expect_create_reject TXGEN_KEY_5 maxfee "$below" "$code" \
    "under min gas price"; then
    fail_case "tx4 (1559 fee cap $below) was not rejected"
fi

# tx2, tx3, tx5, tx6: the at-floor and above shapes must seal. The rejects
# consumed no nonces, so the four seals take n, n+1, n+2, n+3.
h2=$(create_from TXGEN_KEY_5 legacy "$floor" "$code" "$n" 2>&1) ||
    fail_case "tx2 (legacy $floor) rejected: $h2"
h3=$(create_from TXGEN_KEY_5 legacy "$above" "$code" "$((n + 1))" 2>&1) ||
    fail_case "tx3 (legacy $above) rejected: $h3"
h5=$(create_from TXGEN_KEY_5 maxfee "$floor" "$code" "$((n + 2))" 2>&1) ||
    fail_case "tx5 (1559 fee cap $floor) rejected: $h5"
h6=$(create_from TXGEN_KEY_5 tip 0 "$code" "$((n + 3))" 2>&1) ||
    fail_case "tx6 (1559 tip 0) rejected: $h6"

# every accepted create must seal, with the effective price its shape implies
e2=$(receipt_field "$h2" effectiveGasPrice 60) || fail_case "tx2 never sealed"
e3=$(receipt_field "$h3" effectiveGasPrice 60) || fail_case "tx3 never sealed"
e5=$(receipt_field "$h5" effectiveGasPrice 60) || fail_case "tx5 never sealed"
e6=$(receipt_field "$h6" effectiveGasPrice 60) || fail_case "tx6 never sealed"
[ "$(hex2dec "$e2")" = "$floor" ] || fail_case "tx2 effective=$(hex2dec "$e2")"
[ "$(hex2dec "$e3")" = "$above" ] || fail_case "tx3 effective=$(hex2dec "$e3")"
[ "$(hex2dec "$e5")" = "$floor" ] || fail_case "tx5 effective=$(hex2dec "$e5")"
[ "$(hex2dec "$e6")" = "$floor" ] || fail_case "tx6 effective=$(hex2dec "$e6")"

ev="tx1/tx4 rejected at $below"
ev="$ev; sealed tx2=$(hex2dec "$e2") tx3=$(hex2dec "$e3")"
ev="$ev tx5=$(hex2dec "$e5") tx6=$(hex2dec "$e6") wei"
pass_case "$ev"
