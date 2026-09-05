#!/bin/bash
# T30 — filling S4's nonce gap at the new floor promotes the parked 700 gwei
# survivor and it seals at its OWN price — the sweep only drops, it never
# reprices. The runner places this case right after T24 and well before
# t43's rewind so the seal block is re-imported by t44's sync. #2532
# (The pre-fork half of this pair is T21.)
source "$(dirname "$0")/gas2500x-lib.sh"
begin_case "T30" "seal the parked 700 gwei tx above the new floor (post-fork tier)" 2.1

S4_ADDR=$(addr_of TXGEN_KEY_4)
S4_TO=$(addr_of TXGEN_KEY_1)
MARKER=/tmp/g2500-t21-hashes
SURVIVOR_WEI=700000000000    # 700 gwei — strictly above the 625 gwei floor

# the pre side (T21) must have seeded the survivor on this chain
[ -f "$MARKER" ] || skip_case "no T21 pre side on this chain (no $MARKER)"
hash=$(tail -n 1 "$MARKER")
gap=$(send_from TXGEN_KEY_4 "$S4_TO" 1 "$GAS2500_WEI" "$(pending_nonce "$S4_ADDR")")
[ -n "$gap" ] || fail_case "gap fill rejected"

status=$(hex2dec "$(receipt_field "$hash" status 60)")
eff=$(hex2dec "$(receipt_field "$hash" effectiveGasPrice 5)")
blocknum=$(hex2dec "$(receipt_field "$hash" blockNumber 5)")
[ "$status" = "1" ] || fail_case "survivor not sealed (status=$status)"
[ "$eff" = "$SURVIVOR_WEI" ] || fail_case "effectiveGasPrice=$eff != $SURVIVOR_WEI"
pass_case "survivor sealed in block $blocknum at $eff wei"
