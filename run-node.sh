#!/bin/bash
set -eo pipefail

function help() {
    echo
    echo "About:"
    echo "    This script start one or more node in private network."
    echo
    echo "Usage"
    echo "    $0 [options]"
    echo "    $0 <node_id> ..."
    echo
    echo "Options:"
    echo "    -h, --help     display this help"
    echo
    echo "Examples:"
    echo "    $0 -h         Display this help messages"
    echo "    $0 --help     Display this help messages"
    echo "    $0 0          Start 1 node which node_id is 0"
    echo "    $0 1 2        Start 2 nodes which node_id are 1, 2"
    echo "    $0 0 1 2      Start 3 nodes which node_id are 0, 1, 2"
    echo
}

function set_enode() {
    if [ ! -f bootnode.key ]; then
        echo "create bootnode.key"
        ${BOOTNODE_BIN_FILE} -genkey bootnode.key
    fi

    if [ ! -f bootnode.txt ]; then
        echo "create bootnode.txt"
        ${BOOTNODE_BIN_FILE} -nodekey bootnode.key >bootnode.txt 2>&1 &
        PID=$!
        sleep 1
        kill ${PID}
    fi

    # ENODE="enode://62457be5ca9c9ba3913d1513c22ca963b94548a7db06e7a629fec5b654ab7b09a704cba22229107b3f54848ae58e845dcce98393b48be619cc2860d56dd57198@127.0.0.1:30301"
    ENODE="$(grep -Eo 'enode://[0-9a-f]*' bootnode.txt)@127.0.0.1:30301"
}

function start_bootnode() {
    echo "Starting the bootnode"
    ${BOOTNODE_BIN_FILE} -nodekey bootnode.key --addr 0.0.0.0:30301 >/dev/null 2>&1 &
    PID=$!
    echo ${PID} >${BOOTNODE_PID_FILE}
    echo "bootnode is running now: ${PID}"
}

function ensure_node_key() {
    NODE_ID=$1
    DATA_DIR="nodes/pn${NODE_ID}"
    NODE_KEY_FILE="${DATA_DIR}/XDC/nodekey"

    if [ ! -f "${NODE_KEY_FILE}" ]; then
        echo "create node key for pn${NODE_ID}"
        mkdir -p "${DATA_DIR}/XDC"
        ${BOOTNODE_BIN_FILE} -genkey "${NODE_KEY_FILE}"
    fi
}

function node_enode() {
    NODE_ID=$1
    NODE_KEY_FILE="nodes/pn${NODE_ID}/XDC/nodekey"
    NODE_PORT=$((BASE_PORT + NODE_ID))

    PUBKEY="$(${BOOTNODE_BIN_FILE} -nodekey "${NODE_KEY_FILE}" -writeaddress)"
    echo "enode://${PUBKEY}@127.0.0.1:${NODE_PORT}"
}

function write_static_nodes_config() {
    NODE_ID=$1
    shift

    NODE_NAME="pn${NODE_ID}"
    DATA_DIR="nodes/${NODE_NAME}"
    CONFIG_FILE="${DATA_DIR}/XDC/config.toml"

    mkdir -p "${DATA_DIR}/XDC"

    {
        echo "[Node.P2P]"
        echo "StaticNodes = ["
        for PEER_ID in "$@"; do
            if [ "${PEER_ID}" = "${NODE_ID}" ]; then
                continue
            fi
            echo "  \"$(node_enode "${PEER_ID}")\","
        done
        echo "]"
    } >"${CONFIG_FILE}"
}

function prepare_static_nodes() {
    ALL_NODE_IDS=()

    if [ -f .env ]; then
        while IFS= read -r LINE; do
            if [[ ${LINE} =~ ^[[:space:]]*PRIVATE_KEY_([0-9]+)[[:space:]]*= ]]; then
                ALL_NODE_IDS+=("${BASH_REMATCH[1]}")
            fi
        done < .env
    fi

    if [ ${#ALL_NODE_IDS[@]} -eq 0 ]; then
        for ENV_NAME in $(env | cut -d= -f1); do
            if [[ ${ENV_NAME} =~ ^PRIVATE_KEY_([0-9]+)$ ]]; then
                ALL_NODE_IDS+=("${BASH_REMATCH[1]}")
            fi
        done
    fi

    if [ ${#ALL_NODE_IDS[@]} -eq 0 ]; then
        ALL_NODE_IDS=("$@")
    fi

    for NODE_ID in "${ALL_NODE_IDS[@]}"; do
        ensure_node_key "${NODE_ID}"
    done

    for NODE_ID in "$@"; do
        write_static_nodes_config "${NODE_ID}" "${ALL_NODE_IDS[@]}"
    done
}

function start_node() {
    NODE_ID=$1
    NODE_NAME="pn${NODE_ID}"
    PID_FILE="${NODE_NAME}.pid"
    DATA_DIR="nodes/${NODE_NAME}"
    CONFIG_FILE="${DATA_DIR}/XDC/config.toml"
    LOG_FILE="${LOG_DIR}/${NODE_NAME}-${DATE}.log"
    PORT=$((BASE_PORT + NODE_ID))
    RPC_PORT=$((BASE_RPC_PORT + NODE_ID))
    WS_RPC_PORT=$((BASE_WS_RPC_PORT + NODE_ID))
    METRICS_PORT=$((BASE_METRICS_PORT + NODE_ID))

    echo "Starting the node ${NODE_NAME}"

    if [ ! -d "${DATA_DIR}/XDC/chaindata" ]; then
        PRIVATE_KEY_NAME="PRIVATE_KEY_${NODE_ID}"
        PRIVATE_KEY="${!PRIVATE_KEY_NAME}"
        if [[ ${#PRIVATE_KEY} -eq 66 && (${PRIVATE_KEY:0:2} = "0x" || ${PRIVATE_KEY:0:2} = "0X") ]]; then
            PRIVATE_KEY=${PRIVATE_KEY:2}
        fi
        if [[ ${#PRIVATE_KEY} != 64 || ${PRIVATE_KEY} =~ [^0-9a-fA-F] ]]; then
            echo "${PRIVATE_KEY_NAME} is invalid: ${PRIVATE_KEY}"
            exit 5
        fi

        WALLET=$(${XDC_BIN} account import --password .pwd --datadir "${DATA_DIR}" <(echo "${PRIVATE_KEY}") | awk -v FS="({|})" '{print $2}')
        if [ ! -f genesis.json ]; then
            cp genesis/localnet.json genesis.json
        fi
        ${XDC_BIN} init --datadir "${DATA_DIR}" genesis.json
    else
        WALLET=$(${XDC_BIN} account list --datadir "${DATA_DIR}" | head -n 1 | awk -v FS="({|})" '{print $2}')
    fi

    if [ "${WALLET:0:3}" = "xdc" ]; then
        WALLET=${WALLET:3}
    fi

    if [ "${WALLET:0:2}" != "0x" ]; then
        WALLET="0x${WALLET}"
    fi

    echo "PORT = ${PORT}"
    echo "RPC_PORT = ${RPC_PORT}"
    echo "WS_RPC_PORT = ${WS_RPC_PORT}"
    echo "DATA_DIR = ${DATA_DIR}"
    echo "LOG_FILE = ${LOG_FILE}"
    echo "WALLET = ${WALLET}"

    nohup "${XDC_BIN}" \
        --config "${CONFIG_FILE}" \
        --gcmode archive \
        --syncmode full \
        --bootnodes "${ENODE}" \
        --datadir "${DATA_DIR}" \
        --networkid "${NETWORK_ID}" \
        --verbosity "${VERBOSITY}" \
        --gasprice "1" \
        --targetgaslimit 4700000 \
        --password .pwd \
        --unlock "${WALLET}" \
        --port "${PORT}" \
        --rpc \
        --rpcaddr "0.0.0.0" \
        --rpcport "${RPC_PORT}" \
        --rpcapi admin,eth,debug,miner,net,rpc,txpool,web3,XDPoS \
        --rpccorsdomain "*" \
        --rpcvhosts "*" \
        --ws \
        --wsaddr "0.0.0.0" \
        --wsport "${WS_RPC_PORT}" \
        --wsorigins "*" \
        --metrics \
        --metrics-addr "0.0.0.0" \
        --metrics-port "${METRICS_PORT}" \
        >"${LOG_FILE}" 2>&1 &

    PID=$!
    echo ${PID} >"${PID_FILE}"
    echo "node ${NODE_NAME} is running now, PID = ${PID}"
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

for arg in "$@"; do
    if [[ ${arg} =~ [^0-9] ]]; then
        echo "node_id ${arg} is not integer"
        exit 2
    fi

    NODE_NAME="pn${arg}"
    PID_FILE="${NODE_NAME}.pid"
    if [ -f "${PID_FILE}" ]; then
        PID=$(cat "${PID_FILE}")
        if [ -d "/proc/${PID}/fd" ]; then
            echo "please stop node ${NODE_NAME}[${PID}] first: found file ${PID_FILE}"
            exit 3
        fi
    fi
done

if [ -f .env ]; then
    set -a
    # shellcheck disable=SC1091
    . ./.env
    set +a
else
    echo "Not found file .env"
    exit 4
fi

DATE=$(date +%Y%m%d-%H%M%S)
BOOTNODE_PID_FILE="bootnode.pid"

LOG_DIR="${LOG_DIR:-logs}"
VERBOSITY="${VERBOSITY:-3}"
NETWORK_ID="${NETWORK_ID:-5151}"

BASE_PORT="${BASE_PORT:-30000}"
BASE_RPC_PORT="${BASE_RPC_PORT:-8545}"
BASE_WS_RPC_PORT="${BASE_WS_RPC_PORT:-9545}"
BASE_METRICS_PORT="${BASE_METRICS_PORT:-6060}"

XDC_BIN="${XDC:-${HOME}/XDPoSChain/build/bin/XDC}"
BOOTNODE_BIN_FILE="${XDC_BIN%/*}/bootnode"

echo
set_enode
echo "XDC = ${XDC_BIN}"
echo "bootnode = ${BOOTNODE_BIN_FILE}"
echo "ENODE = ${ENODE}"

echo
if [ -f ${BOOTNODE_PID_FILE} ]; then
    PID=$(cat ${BOOTNODE_PID_FILE})
    if [ -d "/proc/${PID}/fd" ]; then
        echo "bootnode is already running: ${PID}"
    else
        start_bootnode
    fi
else
    start_bootnode
fi

echo
touch .pwd
mkdir -p "${LOG_DIR}"
prepare_static_nodes "$@"
for arg in "$@"; do
    start_node "${arg}"
done
