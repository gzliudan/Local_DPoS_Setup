#!/bin/bash
# T23 — sealing continuity across the fork: heads advance in lockstep.
source "$(dirname "$0")/gas2500x-lib.sh"
begin_case "T23" "sealing continuity across the fork" 94.5

wait_head $((FORK_BLOCK + 5)) 240 || fail_case "pn3 head never passed $((FORK_BLOCK + 5))"

h0b=$(head0)
# masternode head sampled now must agree with pn3 within 1 block
h3b=$(head3)
diff=$((h0b > h3b ? h0b - h3b : h3b - h0b))
[ "$diff" -le 1 ] || fail_case "heads diverge: pn0=$h0b pn3=$h3b"
[ "$h0b" -ge $((FORK_BLOCK + 5)) ] || fail_case "masternodes stalled at $h0b"
pass_case "all heads past $((FORK_BLOCK + 5)), pn0=$h0b pn3=$h3b"
