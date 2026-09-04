#!/bin/bash
# T29 — revival when the floor drops (#2541): isolate pn3, rewind below the
# fork with debug.setHead, and the hold-back queue revives on the next
# tracker recheck.
source "$(dirname "$0")/gas2500x-lib.sh"
begin_case "T29" "revival when the floor drops"

XDC_BIN="${XDC:-$HOME/XDPoSChain/build/bin/XDC}"
[ -x "$XDC_BIN" ] || fail_case "XDC binary not found"
[ -d nodes/pn3/XDC/chaindata ] || fail_case "pn3 not initialized"

k0=$(meter3 txpool_local_belowfloor); k0=${k0:-0}
[ "$k0" -gt 0 ] || fail_case "gauge=0, nothing held back to revive"

echo "  stopping regular pn3"
./stop-network.sh 3 >/dev/null 2>&1

echo "  starting pn3 isolated (--nodiscover, no static peers)"
mv nodes/pn3/XDC/config.toml nodes/pn3/XDC/config.toml.bak 2>/dev/null
printf '[Node.P2P]\nStaticNodes = [\n]\n' > nodes/pn3/XDC/config.toml

WALLET=$("$XDC_BIN" account list --datadir nodes/pn3 2>/dev/null |
    head -n 1 | awk -v FS="({|})" '{print $2}')
nohup "$XDC_BIN" --config nodes/pn3/XDC/config.toml --nodiscover \
    --gcmode archive --syncmode full --datadir nodes/pn3 \
    --networkid "${NETWORK_ID:-5151}" --verbosity 5 --gasprice 1 \
    --targetgaslimit 4700000 --password .pwd --unlock "$WALLET" \
    --port 30003 --rpc --rpcaddr 0.0.0.0 --rpcport 8548 \
    --rpcapi admin,eth,debug,miner,net,rpc,txpool,web3,XDPoS \
    --rpccorsdomain "*" --rpcvhosts "*" --ws --wsaddr 0.0.0.0 \
    --wsport 9548 --wsorigins "*" --metrics --metrics-addr 0.0.0.0 \
    --metrics-port 6063 >>logs/pn3-t29-isolated.log 2>&1 &
echo $! >pn3.pid

for _ in $(seq 1 30); do
    head=$(head3) && [ -n "$head" ] && break
    sleep 1
done
[ -n "$head" ] || fail_case "isolated pn3 RPC did not come up"

peers=$(rpc3 admin_peers | jq 'length')
[ "$peers" = "0" ] || fail_case "pn3 has $peers peers, isolation failed"

echo "  rewinding head to 30"
rpc3 debug_setHead "[\"$(printf '0x%x' 30)\"]" >/dev/null || fail_case "setHead failed"
sleep 2

# revival: within one recheck (10 s initial / 60 s period) the held-back txs
# must be resubmitted; poll for 150 s.
revived=0
for _ in $(seq 1 30); do
    sleep 5
    k=$(meter3 txpool_local_belowfloor); k=${k:-0}
    [ "$k" = "0" ] && { revived=1; break; }
done
[ "$revived" = "1" ] || fail_case "gauge never dropped to 0 within 150 s"

# veto: no below-floor tx may ever be sealed afterwards
h=$(head3)
bf=$(hex2dec "$(rpc3 eth_getBlockByNumber "[\"latest\", false]" | jq -r .baseFeePerGas)")
[ "$bf" = "$GAS50_WEI" ] || pass_case "revived at rewound head $h (floor back at 12.5g)"

echo "  restoring regular pn3"
./stop-network.sh 3 >/dev/null 2>&1
mv nodes/pn3/XDC/config.toml.bak nodes/pn3/XDC/config.toml 2>/dev/null
./run-node.sh 3 >/dev/null 2>&1 || fail_case "pn3 rejoin failed"
wait_head $((FORK_BLOCK + 2)) 180 || fail_case "pn3 never resynced past the fork"
pass_case "revived after rewind; pn3 resynced and re-swept"
