#!/bin/bash
set -eo pipefail

if [[ -f .env ]]; then
    export $(cat .env | sed '/^\s*#/d' | xargs)
fi

NETWORK="apothem"
DATE="$(date +%Y%m%d-%H%M%S)"

LOG_DIR="${LOG_DIR:-logs}"
VERBOSITY="${VERBOSITY:-3}"
PORT="${APOTHEM_PORT:-30303}"
WS_PORT="${APOTHEM_WS_PORT:-8546}"
RPC_PORT="${APOTHEM_RPC_PORT:-8545}"
XDPoSChain="${XDPoSChain:-${HOME}/XDPoSChain}"

DATA_DIR="${HOME}/.${NETWORK}"
PID_FILE="${NETWORK}-sync.pid"
XDC_BIN="${XDPoSChain}/build/bin/XDC"
BRANCH=$(cd "${XDPoSChain}" && git branch --show-current)
COMMIT=$(cd "${XDPoSChain}" && git log --pretty=format:'%h: %s' -1)
LOG_FILE="${LOG_DIR}/${NETWORK}-${BRANCH}-${DATE}.log"


if [[ ! -f genesis-${NETWORK}.json ]]; then
    wget https://raw.githubusercontent.com/XinFinOrg/Local_DPoS_Setup/apothem/genesis/genesis.json -O genesis-${NETWORK}.json
fi

if [[ "${APOTHEM_SNAPSHOT_FILE}" != "" && ! -f "${APOTHEM_SNAPSHOT_FILE}" ]]; then
    wget -c -t 0 "https://downloads.apothem.network/${APOTHEM_SNAPSHOT_FILE}"
fi


rm -f .pwd
touch .pwd
mkdir -p ${LOG_DIR}


if [[ ! -d ${DATA_DIR}/keystore ]]; then
    WALLET=$(${XDC_BIN} account new --password .pwd --datadir ${DATA_DIR} | awk -F '[{}]' '{print $2}')
    ${XDC_BIN} --datadir ${DATA_DIR} init genesis-${NETWORK}.json
else
    WALLET=$(${XDC_BIN} account list --datadir ${DATA_DIR} | head -n 1 | awk -F '[{}]' '{print $2}')
fi

if [[ -f "${APOTHEM_SNAPSHOT_FILE}" && ! -f "${DATA_DIR}/XDC/nodekey" ]]; then
    mv "${DATA_DIR}/XDC" "${DATA_DIR}/XDC.bak"
    tar -xvf "${APOTHEM_SNAPSHOT_FILE}" -C ${DATA_DIR}
fi

if [[ ${WALLET:0:3} == "xdc" ]]; then
    WALLET=${WALLET:3}
fi
if [[ ${WALLET:0:2} != "0x" ]]; then
    WALLET="0x${WALLET}"
fi
echo "${WALLET}" >"coinbase-${NETWORK}.txt"

echo
echo "XDPoSChain = ${XDPoSChain}"
echo "branch = ${BRANCH}"
echo "commit = ${COMMIT}"
echo "WALLET = ${WALLET}"
echo "DATA_DIR = ${DATA_DIR}"

# setup bootnodes list
bootnodes=""
input="bootnodes-${NETWORK}.txt"
if [[ -f ${input} ]]; then
    while IFS= read -r line; do
        if [[ "${bootnodes}" == "" ]]; then
            bootnodes=${line}
        else
            bootnodes="${bootnodes},${line}"
        fi
    done <"${input}"
fi


${XDC_BIN} \
    --apothem \
    --port ${PORT} \
    --networkid 51 \
    --syncmode "full" \
    --gcmode "archive" \
    --enable-0x-prefix \
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
    --wsorigins "*" \
    --bootnodes "${bootnodes}" \
    --gasprice 1 \
    --targetgaslimit 420000000 \
    --password ".pwd" \
    --unlock "${WALLET}" \
    &> "${LOG_FILE}" &

PID=$!

echo "Sync PID = ${PID}"
echo "Log file = ${LOG_FILE}"
echo ${PID} >${PID_FILE}
echo
