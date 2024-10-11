#!/bin/bash
set -e

net="$1"
if [[ ${net} == "RPC" || ${net} == "rpc" ]]; then
    RPC="${RPC}"
elif [[ ${net} == "local" ]]; then
    RPC="http://localhost:8545/"
elif [[ ${net} == "dev" ]]; then
    RPC="https://devnetstats.apothem.network/devnet/"
elif [[ ${net} == "test" || ${net} == "apothem" ]]; then
    RPC="https://earpc.apothem.network/"
elif [[ ${net} == "main" || ${net} == "xinfin" ]]; then
    RPC="https://earpc.xinfin.network/"
else
    echo "About: check blockHash in the latest blocks' logs"
    echo "Usage: $0 [local | dev | test | apothem | main | xinfin] <count>"
    exit 1
fi

count="$2"
if [[ -z ${count} ]]; then
    count=10
fi

echo "net=${net} count=${count} RPC=${RPC}"

# get the latest block number from eth_getBlockByNumber
function get_latest_block_number() {
    curl -s -X POST -H "Content-Type: application/json" ${RPC} -d '
    {
      "jsonrpc": "2.0",
      "id": 1001,
      "method": "eth_getBlockByNumber",
      "params": [
        "latest",
        false
      ]
    }' | jq -r '.result.number'
}

# get the block hash from eth_getBlockByNumber
function get_hash_in_block() {
    number="$1"

    curl -s -X POST -H "Content-Type: application/json" ${RPC} -d '
    {
      "jsonrpc": "2.0",
      "id": 1002,
      "method": "eth_getBlockByNumber",
      "params": [
         "'"${number}"'",
        false
      ]
    }' | jq -r '.result.hash'
}

# get the block hash from eth_getLogs
function get_hash_in_logs() {
    number="$1"

    curl -s -X POST -H "Content-Type: application/json" ${RPC} -d '{
        "jsonrpc": "2.0",
        "id": 1003,
        "method": "eth_getLogs",
        "params": [
            {
                "fromBlock": "'"${number}"'",
                "toBlock": "'"${number}"'"
            }
        ]
    }' | jq -r '.result[].blockHash' | sort | uniq
}

begin_hex=$(get_latest_block_number)
begin_dec=$(printf %d ${begin_hex})
end_dec=$(expr ${begin_dec} - ${count})

for ((i = ${begin_dec}; i > ${end_dec}; i--)); do
    echo -n "${i}"
    number_hex=$(printf '0x%x' ${i})

    hash1=$(get_hash_in_block ${number_hex})
    echo -n ": hash=${hash1}"

    hash2=$(get_hash_in_logs ${number_hex})
    if [[ "${hash1}" != "${hash2}" ]] && [[ "${hash2}" != "" ]]; then
        echo -n ", wrong=${hash2}"
    fi

    echo
done

echo
