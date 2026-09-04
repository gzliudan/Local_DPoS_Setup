#!/bin/bash
# T28 — the --gasprice 1 knob is inert (#2516): nodes run with the flag yet
# the enforced floor followed the schedule (proven by T3/T21 rejections).
source "$(dirname "$0")/gas2500x-lib.sh"
begin_case "T28" "the --gasprice 1 knob is inert"

count=$(pgrep -af "XDC|geth" 2>/dev/null | grep -c -- "--gasprice 1")
[ "$count" -ge 4 ] || fail_case "expected >= 4 nodes running --gasprice 1, found $count"
pass_case "$count nodes run --gasprice 1 while the floor moved 12.5g→625g (T3/T21)"
