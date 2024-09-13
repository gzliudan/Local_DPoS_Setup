#!/bin/bash
set -eo pipefail

function help() {
    echo
    echo "About:"
    echo "    This script start a sync node by cfg."
    echo
    echo "Usage"
    echo "    $0 [options]"
    echo "    $0 [CFG]"
    echo
    echo "Options:"
    echo "    -h, --help     display this help"
    echo
    echo "Examples:"
    echo "    $0 -h         Display this help messages"
    echo "    $0 --help     Display this help messages"
    echo "    $0            Start a sync node with default config"
    echo "    $0 8545       Start a sync node with 8545.env"
    echo "    $0 8546.env   Start a sync node with 8546.env"
    echo
}

if [[ "$#" == 1 ]] && [[ "$1" == "-h" || "$1" == "--help" ]]; then
    help
    exit 0
fi

if [[ $# == 0 ]]; then
    CFG="def"
else
    # set config file
    CFG_FILE="$1"
    if [[ ! -f "${CFG_FILE}" ]]; then
        echo "Not find CFG_FILE: ${CFG_FILE}"
        exit 1
    fi
    CFG="$(basename ${CFG_FILE} .env)"

    # get env from config file
    set -a
    # shellcheck source=/dev/null
    source <(sed -e '/^#/d;/^\s*$/d' -e "s/'/'\\\''/g" -e "s/=\(.*\)/='\1'/g" "${CFG_FILE}")
    set +a
fi

NETWORK="devnet"
LOG_DIR="logs"
WORK_DIR=${PWD}
DATE="$(date +%Y%m%d-%H%M%S)"
BOOTNODES_FILE="bootnodes-${NETWORK}.txt"

VERBOSITY="${VERBOSITY:-3}"
PORT="${PORT:-38345}"
RPC_PORT="${RPC_PORT:-8845}"
WS_PORT="${WS_PORT:-9845}"
DATA_DIR="${DATA_DIR:-${HOME}/xdc_data/${NETWORK}_${CFG}}"
XDC_SRC="${XDC_SRC:-${HOME}/XDPoSChain}"
XDC_BIN="${XDC_BIN:-${XDC_SRC}/build/bin/XDC}"

cd "${XDC_SRC}"
cp common/constants/constants.go.devnet common/constants.go
make all
BRANCH=$(git branch --show-current)
COMMIT=$(git log --format=%h --abbrev=8 -1)
if [[ "${BRANCH}" == "" ]]; then
    CODE="${COMMIT}"
else
    CODE="${BRANCH}-${COMMIT}"
fi
LOG_FILE="${LOG_DIR}/${CFG}_${CODE}_${DATE}.log"

cd "${WORK_DIR}"
if [ ! -f genesis-${NETWORK}.json ]; then
    wget https://raw.githubusercontent.com/XinFinOrg/Local_DPoS_Setup/${NETWORK}/genesis/genesis.json -O genesis-${NETWORK}.json
fi

if [[ ! -f .pwd ]]; then
    touch .pwd
fi

mkdir -p "${DATA_DIR}"
mkdir -p "${LOG_DIR}"

if [ ! -d "${DATA_DIR}/keystore" ]; then
    echo
    echo "init data dir: ${DATA_DIR}"
    ${XDC_BIN} --datadir "${DATA_DIR}" init genesis-${NETWORK}.json
fi

# setup bootnodes list
BOOTNODES=""
if [[ -f "${BOOTNODES_FILE}" ]]; then
    echo "read bootnodes from file ${BOOTNODES_FILE}:"
    while IFS= read -r line; do
        echo "${line}"
        if [[ "${BOOTNODES}" == "" ]]; then
            BOOTNODES=${line}
        else
            BOOTNODES="${BOOTNODES},${line}"
        fi
    done <"${BOOTNODES_FILE}"
fi

nohup "${XDC_BIN}" \
    --port "${PORT}" \
    --networkid 551 \
    --etherbase 0x0000000000000000000000000000000000abcdef \
    --syncmode full \
    --gcmode archive \
    --enable-0x-prefix \
    --verbosity "${VERBOSITY}" \
    --datadir "${DATA_DIR}" \
    --XDCx.datadir "${DATA_DIR}/XDCx" \
    --rpc \
    --rpcaddr 0.0.0.0 \
    --rpcport "${RPC_PORT}" \
    --rpcapi admin,db,eth,debug,miner,net,shh,txpool,web3,XDPoS \
    --rpccorsdomain "*" \
    --rpcvhosts "*" \
    --ws \
    --wsaddr 0.0.0.0 \
    --wsport "${WS_PORT}" \
    --wsapi "admin,db,eth,debug,net,shh,txpool,web3,XDPoS" \
    --wsorigins "*" \
    --bootnodes "${BOOTNODES}" \
    --gasprice 1 \
    --targetgaslimit 420000000 \
    --password ".pwd" \
    --rpcwritetimeout "300s" \
    &>"${LOG_FILE}" &

PID=$!
PID_FILE="${NETWORK}-${CFG}-sync-${PID}.pid"
echo ${PID} >${PID_FILE}

echo
echo "datadir = ${DATA_DIR}"
echo "PID_FILE = ${PID_FILE}"
echo "logfile = ${LOG_FILE}"