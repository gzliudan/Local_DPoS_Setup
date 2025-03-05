#!/bin/bash
set -eo pipefail

function help() {
    echo
    echo "About:"
    echo "    This script start a sync node by cfg."
    echo
    echo "Usage"
    echo "    $0 [options]"
    echo "    $0 [CFG_FILE]"
    echo
    echo "Options:"
    echo "    -h, --help     display this help"
    echo
    echo "Examples:"
    echo "    $0 -h             Display this help messages"
    echo "    $0 --help         Display this help messages"
    echo "    $0 mainnet1       Start a sync node with mainnet1.env"
    echo "    $0 testnet2.env   Start a sync node with testnet2.env"
    echo
}

if [[ "$#" != 1 ]]; then
    help
    exit 1
fi

if [[ "${1}" == "-h" || "${1}" == "--help" ]]; then
    help
    exit 0
fi

CFG_FILE="${1}"
if [[ ! -f "${CFG_FILE}" ]]; then
    if [[ "${CFG_FILE##*.}" == "env" ]]; then
        echo "Error: not find configuration file: ${CFG_FILE}"
        exit 2
    else
        CFG_FILE="${CFG_FILE}.env"
        if [[ ! -f "${CFG_FILE}" ]]; then
            echo "Error: not find configuration file: ${1} or ${CFG_FILE}"
            exit 2
        fi
    fi
fi

CFG="$(basename ${CFG_FILE} .env)"

# get env from config file
set -a
# shellcheck source=/dev/null
source <(sed -e '/^#/d;/^\s*$/d' -e "s/'/'\\\''/g" -e "s/=\(.*\)/='\1'/g" "${CFG_FILE}")
set +a

if [[ -z "${NETWORK}" ]]; then
    echo "ERROR: NETWORK is not specified in the file ${CFG_FILE}"
    exit 3
fi

if [[ "$NETWORK" != "mainnet" ]] && [[ "${NETWORK}" != "testnet" ]] && [[ "$NETWORK" != "devnet" ]]; then
    echo "ERROR: NETWORK in the file ${CFG_FILE} must be [ mainnet | testnet | devnet ]"
    exit 4
fi

if [[ -z "${RPC_PORT}" ]]; then
    echo "ERROR: RPC_PORT is not specified in the file ${CFG_FILE}"
    exit 5
fi
DEF_PORT=$((RPC_PORT + 30000))
DEF_WS_PORT=$((RPC_PORT + 1000))

# parameters from the config file
VERBOSITY="${VERBOSITY:-3}"
PORT="${PORT:-${DEF_PORT}}"
WS_PORT="${WS_PORT:-${DEF_WS_PORT}}"
NODE_NO="${NODE_NO:-${RPC_PORT}}"
DATA_DIR="${DATA_DIR:-${HOME}/xdc_chain/${NETWORK}_${NODE_NO}}"
XDC_SRC="${XDC_SRC:-${HOME}/XDPoSChain}"
XDC_BIN="${XDC_BIN:-${XDC_SRC}/build/bin/XDC}"
GCMODE="${GCMODE:-archive}"
SYNCMODE="${SYNCMODE:-full}"

# constant parameters
LOG_DIR="logs"
WORK_DIR=${PWD}
DATE="$(date +%Y%m%d-%H%M%S)"
BOOTNODES_FILE="bootnodes-${NETWORK}.txt"
RPC_API="admin,eth,debug,net,txpool,personal,web3,XDPoS"

cd "${XDC_SRC}"
make all
BRANCH=$(git branch --show-current)
COMMIT=$(git log --format=%h --abbrev=8 -1)
if [[ "${BRANCH}" == "" ]]; then
    LOG_FILE="${LOG_DIR}/${CFG}_${DATE}_${COMMIT}.log"
else
    LOG_FILE="${LOG_DIR}/${CFG}_${BRANCH}_${DATE}_${COMMIT}.log"
fi

cd "${WORK_DIR}"
mkdir -p "${DATA_DIR}"
mkdir -p "${LOG_DIR}"

if [ ! -d "${DATA_DIR}/keystore" ]; then
    echo
    echo "init data dir for ${NETWORK}: ${DATA_DIR}"
    ${XDC_BIN} --datadir "${DATA_DIR}" init ${NETWORK}
fi

if [[ -f "${SNAPSHOT_FILE}" && ! -f "${DATA_DIR}/XDC/nodekey" ]]; then
    mv "${DATA_DIR}/XDC" "${DATA_DIR}/XDC.bak"
    tar -xvf "${SNAPSHOT_FILE}" -C "${DATA_DIR}"
fi

args=(
    --syncmode "${SYNCMODE}"
    --gcmode "${GCMODE}"
    --port "${PORT}"
    --rpcport "${RPC_PORT}"
    --wsport "${WS_PORT}"
    --verbosity "${VERBOSITY}"
    --datadir "${DATA_DIR}"
    --rpcapi "${RPC_API}"
    --wsapi "${RPC_API}"
    --store-reward
)

# Add testnet-specific flag
if [[ "${NETWORK}" = "testnet" ]]; then
    args+=(--testnet)
fi

if [[ -n "${NETWORK_ID}" ]]; then
    args+=(--networkid "${NETWORK_ID}")
fi

nohup "${XDC_BIN}" "${args[@]}" &>"${LOG_FILE}" &

PID=$!
PID_FILE="${CFG}-sync-${PID}.pid"
echo ${PID} >${PID_FILE}

echo
echo "datadir = ${DATA_DIR}"
echo "PID_FILE = ${PID_FILE}"
echo "logfile = ${LOG_FILE}"
