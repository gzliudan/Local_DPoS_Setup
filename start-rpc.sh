#!/bin/bash
set -eo pipefail

function help() {
    echo
    echo "About:"
    echo "    This script start a RPC for private network."
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
    echo "    $0 0         Start a RPC which id is 0"
    echo "    $0 1         Start a RPC which id is 1"
    echo
}

function start_rpc() {
    NODE_ID=$1
    NODE_NAME="on${NODE_ID}"
    PID_FILE="${NODE_NAME}.pid"

    if [ -f "${PID_FILE}" ]; then
        PID=$(cat "${PID_FILE}")
        if [ -d "/proc/${PID}/fd" ]; then
            echo "please stop the RPC ${NODE_NAME}[${PID}] first: found file ${PID_FILE}"
            exit 4
        fi
    fi

    DATA_DIR="nodes/${NODE_NAME}"
    CONFIG_FILE="${DATA_DIR}/XDC/config.toml"
    LOG_FILE="${LOG_DIR}/${NODE_NAME}-${DATE}.log"
    PORT=$((BASE_PORT + NODE_ID))
    RPC_PORT=$((BASE_RPC_PORT + NODE_ID))
    WS_RPC_PORT=$((BASE_WS_RPC_PORT + NODE_ID))

    mkdir -p "${DATA_DIR}"
    if [ ! -d "${DATA_DIR}/XDC/chaindata" ]; then
        echo "init the RPC ${NODE_NAME}"
        ${XDC_BIN} --datadir "${DATA_DIR}" init genesis.json
        echo
    fi

    echo "Starting the RPC ${NODE_NAME}"
    nohup "${XDC_BIN}" \
        --config "${CONFIG_FILE}" \
        --gcmode archive \
        --syncmode full \
        --datadir "${DATA_DIR}" \
        --networkid "${NETWORK_ID}" \
        --verbosity "${VERBOSITY}" \
        --etherbase 0x000000000000000000000000000000000000dead \
        --port ${PORT} \
        --rpc \
        --rpcaddr 0.0.0.0 \
        --rpcport ${RPC_PORT} \
        --rpcapi eth,debug,miner,net,txpool,web3,XDPoS \
        --rpccorsdomain "*" \
        --rpcvhosts "*" \
        --ws \
        --wsaddr 0.0.0.0 \
        --wsport ${WS_RPC_PORT} \
        --wsorigins "*" \
        >"${LOG_FILE}" 2>&1 &

    PID=$!
    echo ${PID} >"${PID_FILE}"

    echo "the RPC ${NODE_NAME} is running now, PID = ${PID}"
    echo "PORT = ${PORT}, RPC_PORT = ${RPC_PORT}, WS_RPC_PORT = ${WS_RPC_PORT}"
    echo "DATA_DIR = ${DATA_DIR}, LOG_FILE = ${LOG_FILE}"
    echo
}

function masternode_enode() {
    MASTER_ID=$1
    MASTER_NODE_KEY_FILE="nodes/pn${MASTER_ID}/XDC/nodekey"
    MASTER_PORT=$((MASTER_BASE_PORT + MASTER_ID))

    PUBKEY="$(${BOOTNODE_BIN_FILE} -nodekey "${MASTER_NODE_KEY_FILE}" -writeaddress)"
    echo "enode://${PUBKEY}@127.0.0.1:${MASTER_PORT}"
}

function write_rpc_static_nodes_config() {
    RPC_ID=$1
    DATA_DIR="nodes/on${RPC_ID}"
    CONFIG_FILE="${DATA_DIR}/XDC/config.toml"

    mkdir -p "${DATA_DIR}/XDC"

    {
        echo "[Node.P2P]"
        echo "StaticNodes = ["
        for MASTER_ID in "${MASTER_NODE_IDS[@]}"; do
            echo "  \"$(masternode_enode "${MASTER_ID}")\","
        done
        echo "]"
    } >"${CONFIG_FILE}"
}

function prepare_rpc_static_nodes() {
    MASTER_NODE_IDS=()

    if [ -f .env ]; then
        while IFS= read -r LINE; do
            if [[ ${LINE} =~ ^[[:space:]]*PRIVATE_KEY_([0-9]+)[[:space:]]*= ]]; then
                MASTER_NODE_IDS+=("${BASH_REMATCH[1]}")
            fi
        done < .env
    fi

    if [ ${#MASTER_NODE_IDS[@]} -eq 0 ]; then
        echo "No master nodes found from PRIVATE_KEY_* in .env"
        exit 5
    fi

    for MASTER_ID in "${MASTER_NODE_IDS[@]}"; do
        if [ ! -f "nodes/pn${MASTER_ID}/XDC/nodekey" ]; then
            echo "Not found masternode key: nodes/pn${MASTER_ID}/XDC/nodekey"
            echo "Please start masternodes first (run-node.sh)"
            exit 6
        fi
    done

    for RPC_ID in "$@"; do
        write_rpc_static_nodes_config "${RPC_ID}"
    done
}

if [ $# == 0 ]; then
    help
    exit 1
fi

if [[ $# == 1 ]] && [[ "$1" == "-h" || "$1" == "--help" ]]; then
    help
    exit 0
fi

for arg in "$@"; do
    if [[ ${arg} =~ [^0-9] ]]; then
        echo "node_id ${arg} is not integer"
        exit 2
    fi

    NODE_NAME="on${arg}"
    PID_FILE="${NODE_NAME}.pid"
    if [ -f "${PID_FILE}" ]; then
        PID=$(cat "${PID_FILE}")
        if [ -d "/proc/${PID}/fd" ]; then
            echo "please stop RPC ${NODE_NAME}[${PID}] first: found file ${PID_FILE}"
            exit 3
        fi
    fi
done

if [ -f .env ]; then
    set -a
    # shellcheck disable=SC1091
    . ./.env
    set +a
fi

DATE=$(date +%Y%m%d-%H%M%S)
XDC_BIN="${XDC:-${HOME}/XDPoSChain/build/bin/XDC}"
BOOTNODE_BIN_FILE="${XDC_BIN%/*}/bootnode"

LOG_DIR="${LOG_DIR:-logs}"
VERBOSITY="${VERBOSITY:-3}"
NETWORK_ID="${NETWORK_ID:-5151}"
MASTER_BASE_PORT="${BASE_PORT:-30000}"
BASE_PORT="${OBSERVER_BASE_PORT:-31000}"
BASE_RPC_PORT="${OBSERVER_BASE_RPC_PORT:-8645}"
BASE_WS_RPC_PORT="${OBSERVER_BASE_WS_RPC_PORT:-9645}"

mkdir -p "${LOG_DIR}"
prepare_rpc_static_nodes "$@"
for arg in "$@"; do
    start_rpc "${arg}"
done
