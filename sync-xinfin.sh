#!/bin/bash
set -eo pipefail

if [[ -f .env ]]; then
    export $(cat .env | sed '/^\s*#/d' | xargs)
fi

NETWORK="xinfin"
DATE="$(date +%Y%m%d-%H%M%S)"

LOG_DIR="${LOG_DIR:-logs}"
VERBOSITY="${VERBOSITY:-3}"
PORT="${XINFIN_PORT:-30303}"
WS_PORT="${XINFIN_WS_PORT:-8546}"
RPC_PORT="${XINFIN_RPC_PORT:-8545}"
XDPoSChain="${XDPoSChain:-${HOME}/XDPoSChain}"

DATA_DIR="${HOME}/.${NETWORK}"
PID_FILE="${NETWORK}-sync.pid"
XDC_BIN="${XDPoSChain}/build/bin/XDC"
BOOTNODES_FILE="bootnodes-${NETWORK}.txt"
BRANCH=$(cd "${XDPoSChain}" && git branch --show-current)
COMMIT=$(cd "${XDPoSChain}" && git log --format=%h --abbrev=8 -1)
LOG_FILE="${LOG_DIR}/${NETWORK}_${BRANCH}_${COMMIT}_${DATE}.log"


if [[ ! -f genesis-${NETWORK}.json ]]; then
    wget https://raw.githubusercontent.com/XinFinOrg/XinFin-Node/master/mainnet/genesis.json -O genesis-${NETWORK}.json
fi

rm -f .pwd
touch .pwd
mkdir -p ${LOG_DIR}


if [[ ! -d ${DATA_DIR}/keystore ]]; then
    echo "create account"
    WALLET=$(${XDC_BIN} account new --password .pwd --datadir ${DATA_DIR} 2>/dev/null | awk -F '[{}]' '{print $2}')
    echo "init datatdir"
    ${XDC_BIN} --datadir ${DATA_DIR} init genesis-${NETWORK}.json 2>/dev/null
else
    WALLET=$(${XDC_BIN} account list --datadir ${DATA_DIR} 2>/dev/null | head -n 1 | awk -F '[{}]' '{print $2}')
fi

if [[ ${WALLET:0:3} == "xdc" ]]; then
    WALLET=${WALLET:3}
fi
if [[ ${WALLET:0:2} != "0x" ]]; then
    WALLET="0x${WALLET}"
fi
echo "${WALLET}" >"coinbase-${NETWORK}.txt"

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
    --port ${PORT} \
    --networkid 50 \
    --syncmode "full" \
    --gcmode "archive" \
    --enable-0x-prefix \
    --periodicprofile \
    --debugdatadir debug-data \
    --verbosity ${VERBOSITY} \
    --datadir "${DATA_DIR}" \
    --rpc \
    --rpcaddr "0.0.0.0" \
    --rpcport ${RPC_PORT} \
    --rpcapi "admin,db,eth,debug,net,shh,txpool,personal,web3,XDPoS" \
    --rpccorsdomain "*" \
    --rpcvhosts "*" \
    --ws \
    --wsaddr "0.0.0.0" \
    --wsport ${WS_PORT} \
    --wsapi "admin,db,eth,debug,net,shh,txpool,personal,web3,XDPoS" \
    --wsorigins "*" \
    --bootnodes "${BOOTNODES}" \
    --gasprice 1 \
    --targetgaslimit 420000000 \
    --password ".pwd" \
    --unlock "${WALLET}" \
    --rpcwritetimeout "300s" \
    &> "${LOG_FILE}" &

PID=$!
echo ${PID} >${PID_FILE}

echo
echo "PID = ${PID}"
echo "datadir = ${DATA_DIR}"
echo "wallet = ${WALLET}"
echo "logfile = ${LOG_FILE}"
