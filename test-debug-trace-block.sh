#!/bin/bash
set -eo pipefail

if [[ $# == 0 ]]; then
    echo "Usage: $0 <cfg1 cfg2 ......>"
    echo "Example: $0 local dev test main"
    exit 1
fi

# read config from file rpc.env
CFG_FILE="rpc.env"

if [[ ! -f "${CFG_FILE}" ]]; then
    echo "Not find config file: ${CFG_FILE}"
    touch ${CFG_FILE}
fi

# read env from config file
vars=$(cat ${CFG_FILE} | sed '/^\s*#/d;/^\s*$/d' | xargs)
if [[ -n "${vars}" ]]; then
    export ${vars}
fi

if [[ -z ${start_number} ]]; then
    start_number=45000000
fi

if [[ -z ${block_count} ]]; then
    block_count=1000
fi

if [[ -z ${loop_times} ]]; then
    loop_times=1
fi

stop_number=$((start_number + block_count))

head_line="start_number: ${start_number}\nstop_number: ${stop_number}\nblock_count: ${block_count}\nloop_times: ${loop_times}"

function get_rpc() {
    cfg="$1"
    if [[ "${cfg}" == "local" ]]; then
        echo "http://localhost:8545/"
    elif [[ "${cfg}" == "dev" ]]; then
        echo "https://devnetstats.apothem.network/devnet/"
    elif [[ ${cfg} == "test" ]]; then
        echo "https://earpc.apothem.network/"
    elif [[ ${cfg} == "main" ]]; then
        echo "https://earpc.xinfin.network/"
    else
        echo "${!arg}"
    fi
}

# verify cfg
for arg in $@; do
    RPC=$(get_rpc ${arg})
    if [[ -z "${RPC}" ]]; then
        echo "Not find ${arg} in config file ${CFG_FILE}"
        exit 2
    fi
done

function report_work() {
    stop_time=$(date +%s)
    elapsed_time=$((stop_time - start_time))
    end_line="stop_number: ${i}\n$(date '+%Y-%m-%d %H:%M:%S'): elapsed ${elapsed_time} seconds"
    echo -e "${end_line}"
    echo -e "${end_line}" >>${file_name}
}

function _interupt() {
    echo
    report_work
    exit
}

test_debug() {
    cfg="$1"
    RPC=$(get_rpc ${arg})
    date_time=$(date '+%Y-%m-%d %H:%M:%S')
    file_name="${cfg}-${start_number}-${stop_number}.txt"

    echo
    echo "${date_time}: ${cfg}"
    echo "log_file: ${file_name}"
    echo "${date_time}" >${file_name}
    echo "RPC: ${RPC}" >>${file_name}
    echo -e "${head_line}" >>${file_name}

    start_time=$(date +%s)
    for ((i = ${start_number}; i < ${stop_number}; i++)); do
        number=$(printf '0x%x' ${i})
        begin_time=$(date +%s)
        for ((j = 0; j < ${loop_times}; j++)); do
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
        done

        end_time=$(date +%s)
        elapsed_time=$((end_time - begin_time))
        echo "T=${elapsed_time} b=${i} B=${number}" >>${file_name}
    done

    report_work
}

trap _interupt INT TERM

echo -e "${head_line}"
for arg in $@; do
    test_debug ${arg}
done
