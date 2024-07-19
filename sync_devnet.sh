#!/bin/bash
set -eo pipefail

NETWORK="devnet"
LOG_DIR="logs"
WORK_DIR=${PWD}
DATE="$(date +%Y%m%d-%H%M%S)"
BOOTNODES_FILE="bootnodes-${NETWORK}.txt"

VERBOSITY="${VERBOSITY:-3}"
PORT="${APOTHEM_PORT:-30303}"
RPC_PORT="${DEVNET_RPC_PORT:-8545}"
WS_PORT="${DEVNET_WS_PORT:-9545}"
DATA_DIR="${DATA_DIR:-${HOME}/xdc_data/${NETWORK}}"
XDPoSChain="${XDPoSChain:-${HOME}/XDPoSChain}"
XDC_BIN="${XDPoSChain}/build/bin/XDC"

cd ${HOME}/XDPoSChain
cp common/constants/constants.go.devnet common/constants.go
make all
BRANCH=$(git branch --show-current)
COMMIT=$(git log --format=%h --abbrev=8 -1)
LOG_FILE="${LOG_DIR}/${NETWORK}-${BRANCH}-${DATE}_${COMMIT}.log"

echo
echo "branch = ${BRANCH}"
echo "commit = $(git log --pretty=format:'%h: %s' -1)"

cd ${WORK_DIR}
mkdir -p "${DATA_DIR}"
mkdir -p "${LOG_DIR}"

if [ ! -f genesis-${NETWORK}.json ]; then
    wget https://raw.githubusercontent.com/XinFinOrg/Local_DPoS_Setup/${NETWORK}/genesis/genesis.json -O genesis-${NETWORK}.json
fi

if [ ! -d ${DATA_DIR}/keystore ]; then
    echo
    echo "init data dir: ${DATA_DIR}"
    ${XDC_BIN} --datadir ${DATA_DIR} init genesis-${NETWORK}.json
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

echo
nohup ${XDC_BIN} \
    --verbosity ${VERBOSITY} \
    --datadir ${DATA_DIR} \
    --networkid 551 \
    --etherbase 0x0000000000000000000000000000000000abcdef \
    --gcmode archive \
    --syncmode full \
    --enable-0x-prefix \
    --rpc \
    --rpcaddr 0.0.0.0 \
    --rpcport ${RPC_PORT} \
    --rpcapi admin,db,eth,debug,miner,net,shh,txpool,web3,XDPoS \
    --rpccorsdomain "*" \
    --rpcvhosts "*" \
    --ws \
    --wsaddr 0.0.0.0 \
    --wsport ${WS_PORT} \
    --wsorigins "*" \
    --bootnodes "${BOOTNODES}" \
    >>"${LOG_FILE}" \
    2>&1 &

PID=$!
PID_FILE="${NETWORK}-${PID}-sync.pid"
echo ${PID} >${PID_FILE}

echo
echo "PID = ${PID}"
echo "datadir = ${DATA_DIR}"
echo "logfile = ${LOG_FILE}"
