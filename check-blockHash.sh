#!/bin/bash
set -e

net="$1"
start_number="$2"
count="$3"

if [[ ${net} == "local" ]]; then
    RPC="http://localhost:8545/"
elif [[ ${net} == "dev" ]]; then
    RPC="https://devnetstats.apothem.network/devnet/"
elif [[ ${net} == "test" || ${net} == "apothem" ]]; then
    RPC="https://earpc.apothem.network/"
elif [[ ${net} == "main" || ${net} == "xinfin" ]]; then
    RPC="https://earpc.xinfin.network/"
    if [[ -z ${start_number} ]]; then
        # blockHash is wrong from 63952057
        start_number=63952057
    fi
else
    echo "Usage: $0 [local | dev | test | apothem | main | xinfin] <start_number>"
    exit 1
fi

if [[ -z ${start_number} ]]; then
    start_number=1
fi

if [[ -z ${count} ]]; then
    count=10
fi

end_number=$(expr ${start_number} + ${count})

echo "$(date '+%Y-%m-%d %H:%M:%S') start_number=${start_number} end_number=${end_number} count=${count} RPC=${RPC} "

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

for ((i = ${start_number}; i < ${end_number}; i++)); do
    echo -n ${i}
    number=$(printf '0x%x' ${i})

    hash1=$(get_hash_in_block ${number})
    echo -n ": hash=${hash1}"

    hash2=$(get_hash_in_logs ${number})
    if [[ "${hash1}" != "${hash2}" ]] && [[ "${hash2}" != "" ]]; then
        echo -n ", wrong=${hash1}"
    fi

    echo
done

echo
