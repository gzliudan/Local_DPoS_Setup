#!/bin/bash
# T18 — sweep observables on pn3 (#2532): meter and trace log.
source "$(dirname "$0")/gas2500x-lib.sh"
begin_case "T18" "sweep observables on pn3"

m=$(meter3 txpool_belowfloor)
[ -n "$m" ] || fail_case "meter txpool/belowfloor missing"
[ "$m" -ge 70 ] || fail_case "meter=$m, expected >= 70"

grep -q "reason=below-gas-price-floor" logs/pn3-*.log 2>/dev/null \
    || fail_case "no 'Dropped pooled transaction ... reason=below-gas-price-floor' in logs"
pass_case "meter=$m, drop log found"
