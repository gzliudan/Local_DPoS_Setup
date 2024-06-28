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
else
    echo "Usage: $0 [local | dev | test | apothem | main | xinfin] <start_number> <count>"
    exit 1
fi

if [[ -z ${start_number} ]]; then
    start_number=1
fi

if [[ -z ${count} ]]; then
    count=10000000
fi

end_number=$(expr ${start_number} + ${count})

log_file="${net}-tx-log-${start_number}-${end_number}.txt"
hash_file="${net}-tx-hash-${start_number}-${end_number}.txt"

echo "$(date '+%Y-%m-%d %H:%M:%S') net=${net}  start_number=${start_number} count=${count} end_number=${end_number} RPC=${RPC}"

# get the trx hashes in transactions array by block number
function get_trx_hash_by_number() {
    curl -s -X POST -H "Content-Type: application/json" ${RPC} -d '
    {
      "jsonrpc": "2.0",
      "id": 1001,
      "method": "eth_getBlockByNumber",
      "params": [
        "'"$1"'",
        true
      ]
    }' | jq -r '.result.transactions[].hash'
}

for ((i = ${start_number}; i < ${end_number}; i++)); do
    echo ${i}
    echo ${i} >>"${log_file}"

    number=$(printf '0x%x' ${i})
    while true; do
        hashes=$(get_trx_hash_by_number ${number})
        if [[ $? == 0 ]]; then
            break
        else
            sleep 5
            echo ${i}
        fi
    done

    if [[ ${hashes} != "" ]]; then
        for hash in ${hashes}; do
            echo "${hash}" >>"${log_file}"
            echo "${i} ${hash}" >>"${hash_file}"
        done
    fi
done
