#!/bin/bash
set -eo pipefail

function help() {
    echo
    echo "About:"
    echo "    This script start an obsrever for private network."
    echo
    echo "Usage"
    echo "    $0 [options]"
    echo "    $0 <node_id>"
    echo
    echo "Options:"
    echo "    -h, --help     display this help"
    echo
    echo "Examples:"
    echo "    $0 -h        Display this help messages"
    echo "    $0 --help    Display this help messages"
    echo "    $0 0         Start an observer which id is 0"
    echo "    $0 1         Start an observer which id is 1"
    echo
}

function start_observer() {
    NODE_ID=$1
    NODE_NAME="on${NODE_ID}"
    PID_FILE="${NODE_NAME}.pid"

    if [ -f "${PID_FILE}" ]; then
        PID=$(cat "${PID_FILE}")
        if [ -d "/proc/${PID}/fd" ]; then
            echo "please stop the observer ${NODE_NAME}[${PID}] first: found file ${PID_FILE}"
            exit 4
        fi
    fi

    DATA_DIR="nodes/${NODE_NAME}"
    LOG_FILE="${LOG_DIR}/${NODE_NAME}-${DATE}.log"
    PORT=$((${BASE_PORT} + ${NODE_ID}))
    RPC_PORT=$((${BASE_RPC_PORT} + ${NODE_ID}))
    WS_RPC_PORT=$((${BASE_WS_RPC_PORT} + ${NODE_ID}))

    mkdir -p ${DATA_DIR}
    if [ ! -d "${DATA_DIR}/XDC/chaindata" ]; then
        echo "init the observer ${NODE_NAME}"
        ${XDC} --datadir ${DATA_DIR} init genesis.json
        echo
    fi

    echo "Starting the observer ${NODE_NAME}"
    ${XDC} \
        --gcmode archive \
        --syncmode full \
        --enable-0x-prefix \
        --bootnodes ${ENODE} \
        --datadir ${DATA_DIR} \
        --networkid ${NETWORK_ID} \
        --verbosity ${VERBOSITY} \
        --etherbase 0x000000000000000000000000000000000000dead \
        --port ${PORT} \
        --rpc \
        --rpcaddr 0.0.0.0 \
        --rpcport ${RPC_PORT} \
        --rpcapi admin,db,eth,debug,miner,net,shh,txpool,personal,web3,XDPoS \
        --rpccorsdomain "*" \
        --rpcvhosts "*" \
        --ws \
        --wsaddr 0.0.0.0 \
        --wsport ${WS_RPC_PORT} \
        --wsorigins "*" \
        >${LOG_FILE} 2>&1 &

    PID=$!
    echo ${PID} >${PID_FILE}

    echo "the observer ${NODE_NAME} is running now, PID = ${PID}"
    echo "PORT = ${PORT}, RPC_PORT = ${RPC_PORT}, WS_RPC_PORT = ${WS_RPC_PORT}"
    echo "DATA_DIR = ${DATA_DIR}, LOG_FILE = ${LOG_FILE}"
    echo
}

if [ $# == 0 ]; then
    help
    exit 1
fi

if [[ $# == 1 ]] && [[ "$1" == "-h" || "$1" == "--help" ]]; then
    help
    exit 0
fi

for arg in $@; do
    if [[ ${arg} =~ [^0-9] ]]; then
        echo "node_id ${arg} is not integer"
        exit 2
    fi

    NODE_NAME="on${arg}"
    PID_FILE="${NODE_NAME}.pid"
    if [ -f "${PID_FILE}" ]; then
        PID=$(cat "${PID_FILE}")
        if [ -d "/proc/${PID}/fd" ]; then
            echo "please stop observer ${NODE_NAME}[${PID}] first: found file ${PID_FILE}"
            exit 3
        fi
    fi
done

DATE=$(date +%Y%m%d-%H%M%S)
XDC="${HOME}/XDPoSChain/build/bin/XDC2"
ENODE="$(grep -Eo 'enode://[0-9a-f]*' bootnode.txt)@127.0.0.1:30301"

if [ -f .env ]; then
    export $(cat .env | sed '/^\s*#/d' | xargs)
fi

LOG_DIR="${LOG_DIR:-logs}"
VERBOSITY="${VERBOSITY:-3}"
NETWORK_ID="${NETWORK_ID:-888}"
BASE_PORT="${OBSERVER_BASE_PORT:-31000}"
BASE_RPC_PORT="${OBSERVER_BASE_RPC_PORT:-8645}"
BASE_WS_RPC_PORT="${OBSERVER_BASE_WS_RPC_PORT:-9645}"

mkdir -p ${LOG_DIR}
for arg in $@; do
    start_observer ${arg}
done
