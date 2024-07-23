#!/bin/bash
set -eo pipefail

if [[ $# == 0 ]]; then
    echo "Usage: $0 [ local | dev | test | apothem | main | xinfin ] <start_number> <block_count>"
    exit 1
fi

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
    RPC="${net}"
fi

if [[ -z ${start_number} ]]; then
    start_number=45000000
fi

if [[ -z ${count} ]]; then
    count=100000
fi

end_number=$(expr ${start_number} + ${count})

file_name="${net}-${start_number}-${end_number}.txt"
echo "log file: ${file_name}"

start_time=$(date +%s)

print_work_time() {
    stop_time=$(date +%s)
    elapsed_time=$((stop_time - start_time))
    end_line="$(date '+%Y-%m-%d %H:%M:%S'): elapsed_seconds=${elapsed_time}, start_number=${start_number}, stop_number=${i}"
    echo
    echo "${end_line}"
    echo "${end_line}" >>${file_name}
}

_interupt() {
    print_work_time
    exit
}

trap _interupt INT TERM

echo -e "$(date '+%Y-%m-%d %H:%M:%S') net=${net} start_number=${start_number} count=${count} end_number=${end_number} RPC=${RPC}" >${file_name}

for ((i = ${start_number}; i < ${end_number}; i++)); do
    number=$(printf '0x%x' ${i})
    begin_time=$(date +%s)
    curl -s -X POST -H "Content-Type: application/json" ${RPC} -d '{
        "jsonrpc": "2.0",
        "id": 1001,
        "method": "debug_traceBlockByNumber",
        "params": [
            "'"${number}"'", {
                "tracer":"callTracer",
                "timeout":"300s"
            }
        ]
    }' >/dev/null

    end_time=$(date +%s)
    elapsed_time=$((end_time - begin_time))
    echo "T=${elapsed_time} b=${i} B=${number}" >>${file_name}
done

print_work_time
