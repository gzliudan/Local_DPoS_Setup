#!/bin/bash
set -eo pipefail

# set config file
if [[ $# == 0 ]]; then
    if [[ -f "xinfin.env" ]]; then
        CFG_FILE="xinfin.env"
    else
        CFG_FILE=".env"
    fi
    CFG="xinfin"
else
    CFG_FILE="$1"
    CFG=$(basename ${CFG_FILE} .env)
fi

if [[ ! -f "${CFG_FILE}" ]]; then
    echo "Not find config file: ${CFG_FILE}"
    echo "Usage: $0 [CONFIG_FILE]"
    exit 1
fi

# read env from config file
set -a
# shellcheck source=/dev/null
source <(sed -e '/^#/d;/^\s*$/d' -e "s/'/'\\\''/g" -e "s/=\(.*\)/='\1'/g" "${CFG_FILE}")
set +a

NETWORK="xinfin"
LOG_DIR="logs"
WORK_DIR=${PWD}
DATE="$(date +%Y%m%d-%H%M%S)"
BOOTNODES_FILE="bootnodes-${NETWORK}.txt"

VERBOSITY="${VERBOSITY:-3}"
PORT="${PORT:-30503}"
RPC_PORT="${RPC_PORT:-8545}"
WS_PORT="${WS_PORT:-9545}"
DATA_DIR="${DATA_DIR:-${HOME}/xdc_data/${NETWORK}}"
XDC_SRC="${XDC_SRC:-${HOME}/XDPoSChain}"
XDC_BIN="${XDC_BIN:-${XDC_SRC}/build/bin/XDC}"

cd "${XDC_SRC}"
git checkout HEAD -- common/constants.go
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
if [[ ! -f genesis-${NETWORK}.json ]]; then
    wget https://raw.githubusercontent.com/XinFinOrg/XinFin-Node/master/mainnet/genesis.json -O genesis-${NETWORK}.json
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

if [[ -f "${XINFIN_SNAPSHOT_FILE}" && ! -f "${DATA_DIR}/XDC/nodekey" ]]; then
    mv "${DATA_DIR}/XDC" "${DATA_DIR}/XDC.bak"
    tar -xvf "${XINFIN_SNAPSHOT_FILE}" -C "${DATA_DIR}"
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
    --networkid 50 \
    --etherbase 0x0000000000000000000000000000000000abcdef \
    --syncmode "full" \
    --gcmode "archive" \
    --enable-0x-prefix \
    --verbosity "${VERBOSITY}" \
    --datadir "${DATA_DIR}" \
    --XDCx.datadir "${DATA_DIR}/XDCx" \
    --rpc \
    --rpcaddr "0.0.0.0" \
    --rpcport "${RPC_PORT}" \
    --rpcapi "admin,db,eth,debug,net,shh,txpool,web3,XDPoS" \
    --rpccorsdomain "*" \
    --rpcvhosts "*" \
    --ws \
    --wsaddr "0.0.0.0" \
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
PID_FILE="${CFG}-${PID}-sync.pid"
echo ${PID} >${PID_FILE}

echo
echo "datadir = ${DATA_DIR}"
echo "PID_FILE = ${PID_FILE}"
echo "logfile = ${LOG_FILE}"
