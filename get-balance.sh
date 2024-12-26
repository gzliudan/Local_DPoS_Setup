#!/bin/bash
set -e

step="${step:-128}"
address="${address:-0xD4CE02705041F04135f1949Bc835c1Fe0885513c}"

test_rpcs=(
    "http://localhost:8545"
    "https://arpc.xinfin.network/"
    "https://earpc.xinfin.network/"
    "https://arpc.xinfin.network/"
    "https://earpc.xinfin.network/"
    "https://rpc.ankr.com/xdc"
)

function fetch_balance() {
    for RPC in $@; do
        number=$(curl -s -X POST -H "Content-Type: application/json" ${RPC} -d '{
            "jsonrpc": "2.0",
            "id": 1001,
            "method": "eth_getBlockByNumber",
            "params": [
                "latest",
                false
            ]
        }' | jq -r '.result.number')

        latest_dec=$(printf %d ${number})
        query_dec=$((latest_dec - step))
        echo
        echo "RPC = ${RPC} , latest number=${latest_dec} , step=${step} , query number=${query_dec}"

        curl -s -X POST -H "Content-Type: application/json" ${RPC} -d '{
            "jsonrpc": "2.0",
            "id": 1002,
            "method": "eth_getBalance",
            "params": [
                "'"${address}"'",
                "'"$(printf '0x%x' ${query_dec})"'"
            ]
        }' | jq
    done
}

if [[ $# > 0 ]]; then
    fetch_balance $@
else
    fetch_balance ${test_rpcs[@]}
fi

echo
