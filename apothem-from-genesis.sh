#!/bin/bash
set -eo pipefail

VERBOSITY=3
RPC_PORT=8545
WS_RPC_PORT=9545
NETWORK="apothem"
MODE="genesis"
DATE=$(date +%Y%m%d-%H%M%S)
DATA_DIR="${HOME}/.${NETWORK}"
WORK_DIR=${PWD}
LOG_DIR="logs"
PID_FILE="${NETWORK}-sync.pid"
XDC="${HOME}/XDPoSChain/build/bin/XDC"

cd ${HOME}
if [ ! -d XDPoSChain ]; then
    git clone https://github.com/XinFinOrg/XDPoSChain.git
    git checkout apothem
    make all
fi

cd XDPoSChain
BRANCH=$(git branch --show-current)
LOG_FILE="${LOG_DIR}/${NETWORK}-${MODE}-${BRANCH}-${DATE}.log"

echo
echo "branch = ${BRANCH}"
echo "commit = $(git log --pretty=format:'%h: %s' -1)"

cd ${WORK_DIR}
mkdir -p ${LOG_DIR}

if [ ! -f genesis-${NETWORK}.json ]; then
    wget https://raw.githubusercontent.com/XinFinOrg/Local_DPoS_Setup/apothem/genesis/genesis.json -O genesis-${NETWORK}.json
fi

if [ ! -d ${DATA_DIR}/keystore ]; then
    echo
    echo "init data dir: ${DATA_DIR}"
    ${XDC} --datadir ${DATA_DIR} init --apothem
fi

bootnodes=""
input="bootnodes-${NETWORK}.txt"
while IFS= read -r line; do
    if [ -z "${bootnodes}" ]; then
        bootnodes=${line}
    else
        bootnodes="${bootnodes},${line}"
    fi
done < "${input}"

echo
nohup ${XDC} \
    --verbosity ${VERBOSITY} \
    --datadir ${DATA_DIR} \
    --networkid 51 \
    --etherbase 0x000000000000000000000000000000000000dead \
    --gcmode archive \
    --syncmode full \
    --enable-0x-prefix \
    --apothem \
    --rpc \
    --rpcaddr 0.0.0.0 \
    --rpcport ${RPC_PORT} \
    --rpcapi admin,db,eth,debug,miner,net,shh,txpool,personal,web3,XDPoS \
    --rpccorsdomain "*" \
    --rpcvhosts "*" \
    --ws \
    --wsaddr 0.0.0.0 \
    --wsport ${WS_RPC_PORT} \
    --wsorigins "*" \
    --bootnodes "${bootnodes}" \
    >> "${LOG_FILE}" \
    2>&1 &

PID=$!

echo "Sync PID = ${PID}"
echo "Log file = ${LOG_FILE}"
echo ${PID} > ${PID_FILE}
echo

