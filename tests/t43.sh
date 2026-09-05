#!/bin/bash
# T43 — revival when the floor drops (#2541).
#
# debug_setHead is a PRIVATE (Local-only) API on this build and is rejected
# over HTTP ("does not exist/is not available"), so the rewind is done at
# STARTUP instead: --set-head 30 rolls the chain back to block 30 before the
# pool is created (eth/backend.go New() runs the rollback), which drops the
# pool floor back to 12.5 gwei. --port 0 gives the node a random P2P port so
# the masternodes' static dials (they still hold pn3's old enode) fail and
# the node stays peerless; admin_addPeer re-connects it in T44.
#
# This script verifies the REVIVAL half: the tracker's first recheck (10 s
# timer) resubmits the journalled hold-backs at the 12.5 gwei floor —
# gauge txpool_local_belowfloor must drop to 0 and the pools must re-fill.
# The node is left ISOLATED and RUNNING for T44 (same process = same meter).
source "$(dirname "$0")/gas2500x-lib.sh"
begin_case "T43" "revival when the floor drops" 11.1

XDC_BIN="${XDC:-$HOME/XDPoSChain/build/bin/XDC}"
[ -x "$XDC_BIN" ] || fail_case "XDC binary not found"
[ -d nodes/pn3/XDC/chaindata ] || fail_case "pn3 not initialized"

k0=$(gauge3 txpool_local_belowfloor)
[ "$k0" -gt 0 ] || fail_case "gauge=0, nothing held back to revive"

stop_pn3 10   # the dying node gets a wider metrics-release window here

mv nodes/pn3/XDC/config.toml nodes/pn3/XDC/config.toml.bak 2>/dev/null
printf '[Node.P2P]\nStaticNodes = [\n]\n' > nodes/pn3/XDC/config.toml

WALLET=$("$XDC_BIN" account list --datadir nodes/pn3 2>/dev/null |
    head -n 1 | awk -v FS="({|})" '{print $2}')
nohup "$XDC_BIN" --config nodes/pn3/XDC/config.toml --nodiscover --port 0 \
    --set-head 30 \
    --gcmode archive --syncmode full --datadir nodes/pn3 \
    --networkid "${NETWORK_ID:-5151}" --verbosity 5 --gasprice 1 \
    --targetgaslimit 4700000 --password .pwd --unlock "$WALLET" \
    --rpc --rpcaddr 0.0.0.0 --rpcport 8548 \
    --rpcapi admin,eth,debug,miner,net,rpc,txpool,web3,XDPoS \
    --rpccorsdomain "*" --rpcvhosts "*" \
    --metrics --metrics-addr 0.0.0.0 --metrics-port 6063 \
    >>logs/pn3-t43-isolated.log 2>&1 &
echo $! >pn3.pid

if ! wait_rpc3 45; then
    restore_pn3
    fail_case "isolated pn3 RPC did not come up"
fi
head=$(head3)
if [ "$head" -ge "$FORK_BLOCK" ]; then
    restore_pn3
    fail_case "rollback to 30 did not take effect (head=$head)"
fi

peers=$(rpc3 admin_peers | jq 'length')
if [ "$peers" != "0" ]; then
    restore_pn3
    fail_case "pn3 has $peers peers, isolation failed"
fi

# revival: the tracker's first recheck fires ~10 s after start and resubmits
# the journalled hold-backs at the 12.5 gwei floor; poll up to ~90 s.
revived=0
pools=""
k=""
for _ in $(seq 1 30); do
    sleep 3
    k=$(gauge3 txpool_local_belowfloor)
    read -r p q <<<"$(pool3)"
    pools="$p/$q"
    if [ "$k" = "0" ] && [ $((p + q)) -ge 18 ]; then revived=1; break; fi
done
if [ "$revived" != "1" ]; then
    restore_pn3
    fail_case "no revival in 90 s: gauge=$k, pools=$pools (expected 0 and >=18)"
fi

# veto: no below-floor tx may ever be sealed afterwards — the node has no
# peers and is not a signer, but assert the floor anyway
bf=$(base_fee latest)
if [ "$bf" != "$GAS50_WEI" ]; then
    restore_pn3
    fail_case "floor is not 12.5g after the rollback (bf=$bf)"
fi

printf 'isolated %s %s\n' "$k0" "$pools" >/tmp/g2500-t43-state
pass_case "revived: gauge $k0->0, pools $pools (floor back at 12.5g, node left isolated for T44)"
