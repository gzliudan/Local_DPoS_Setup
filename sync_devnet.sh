#!/bin/bash
set -eo pipefail

# set config file
if [[ $# == 0 ]]; then
    if [[ -f "devnet.env" ]]; then
        CFG_FILE="devnet.env"
    else
        CFG_FILE=".env"
    fi
    CFG="devnet"
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

NETWORK="devnet"
LOG_DIR="logs"
WORK_DIR=${PWD}
DATE="$(date +%Y%m%d-%H%M%S)"
BOOTNODES_FILE="bootnodes-${NETWORK}.txt"

VERBOSITY="${VERBOSITY:-3}"
PORT="${PORT:-30703}"
RPC_PORT="${RPC_PORT:-8745}"
WS_PORT="${WS_PORT:-9745}"
DATA_DIR="${DATA_DIR:-${HOME}/xdc_data/${NETWORK}}"
XDC_SRC="${XDC_SRC:-${HOME}/XDPoSChain}"
XDC_BIN="${XDC_BIN:-${XDC_SRC}/build/bin/XDC}"

cd "${XDC_SRC}"
cp common/constants/constants.go.devnet common/constants.go
make all
BRANCH=$(git branch --show-current)
COMMIT=$(git log --format=%h --abbrev=8 -1)
LOG_FILE="${LOG_DIR}/${CFG}-${BRANCH}-${DATE}_${COMMIT}.log"

cd "${WORK_DIR}"
if [ ! -f genesis-${NETWORK}.json ]; then
    wget https://raw.githubusercontent.com/XinFinOrg/Local_DPoS_Setup/${NETWORK}/genesis/genesis.json -O genesis-${NETWORK}.json
fi

rm -f .pwd
touch .pwd
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
PID_FILE="${NETWORK}-${PID}-sync.pid"
echo ${PID} >${PID_FILE}

echo
echo "PID = ${PID}"
echo "datadir = ${DATA_DIR}"
echo "logfile = ${LOG_FILE}"
