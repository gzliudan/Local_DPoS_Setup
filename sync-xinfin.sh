#!/bin/bash
set -eo pipefail

if [[ -f .env ]]; then
    export $(cat .env | sed '/^\s*#/d' | xargs)
fi

NETWORK="xinfin"
LOG_DIR="logs"
WORK_DIR=${PWD}
DATE="$(date +%Y%m%d-%H%M%S)"

VERBOSITY="${VERBOSITY:-3}"
PORT="${XINFIN_PORT:-30303}"
RPC_PORT="${XINFIN_RPC_PORT:-8545}"
WS_PORT="${XINFIN_WS_PORT:-9545}"
DATA_DIR="${DATA_DIR:-${HOME}/xdc_data/${NETWORK}}"
XDPoSChain="${XDPoSChain:-${HOME}/XDPoSChain}"
XDC_BIN="${XDPoSChain}/build/bin/XDC"
BOOTNODES_FILE="bootnodes-${NETWORK}.txt"

cd ${HOME}/XDPoSChain
git checkout HEAD -- common/constants.go
make all
BRANCH=$(git branch --show-current)
COMMIT=$(git log --format=%h --abbrev=8 -1)
LOG_FILE="${LOG_DIR}/${NETWORK}_${BRANCH}_${DATE}_${COMMIT}.log"
cd ${WORK_DIR}

if [[ ! -f genesis-${NETWORK}.json ]]; then
    wget https://raw.githubusercontent.com/XinFinOrg/XinFin-Node/master/mainnet/genesis.json -O genesis-${NETWORK}.json
fi

rm -f .pwd
touch .pwd
mkdir -p "${DATA_DIR}"
mkdir -p "${LOG_DIR}"

if [ ! -d ${DATA_DIR}/keystore ]; then
    echo
    echo "init data dir: ${DATA_DIR}"
    ${XDC_BIN} --datadir ${DATA_DIR} init genesis-${NETWORK}.json
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

${XDC_BIN} \
    --port "${PORT}" \
    --networkid 50 \
    --etherbase 0x0000000000000000000000000000000000abcdef \
    --syncmode "full" \
    --gcmode "archive" \
    --enable-0x-prefix \
    --verbosity "${VERBOSITY}" \
    --datadir "${DATA_DIR}" \
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
PID_FILE="${NETWORK}-${PID}-sync.pid"
echo ${PID} >${PID_FILE}

echo
echo "PID = ${PID}"
echo "datadir = ${DATA_DIR}"
echo "logfile = ${LOG_FILE}"
