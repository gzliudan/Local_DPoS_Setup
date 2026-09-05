#!/bin/bash
# T05 — the latest block's baseFeePerGas equals the pre-fork tier price
# (12.5 gwei), #2516. (The post-fork half with the boundary-block step is
# T39.)
source "$(dirname "$0")/gas2500x-lib.sh"
begin_case "T05" "verify the block baseFeePerGas carries the tier price (pre-fork tier)" 0.0

require_pre_fork "pre side missed the window"

bf=$(base_fee latest)
[ "$bf" = "$GAS50_WEI" ] || fail_case "latest baseFee=$bf, expected $GAS50_WEI"
pass_case "baseFeePerGas=$bf wei"
