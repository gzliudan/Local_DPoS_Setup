#!/bin/bash
set -eo pipefail

VERBOSITY=3
RPC_PORT=8545
WS_RPC_PORT=9545
NETWORK="apothem"
MODE="snapshot"
DATA_DIR="${HOME}/.${NETWORK}"
XDC="${HOME}/XDPoSChain/build/bin/XDC"
WORK_DIR=${PWD}
PID_FILE="${WORK_DIR}/${NETWORK}-sync.pid"
LOG_DIR="${WORK_DIR}/logs"
DATE=$(date +%Y%m%d-%H%M%S)

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
    echo
    wget https://raw.githubusercontent.com/XinFinOrg/Local_DPoS_Setup/apothem/genesis/genesis.json -O genesis-${NETWORK}.json
fi

if [ ! -d ${DATA_DIR}/keystore ]; then
    echo
    echo "init data dir: ${DATA_DIR}"
    ${XDC} --datadir ${DATA_DIR} init --apothem
    mv ${DATA_DIR}/XDC ${DATA_DIR}/XDC.bak
fi

if [ ! -d ${DATA_DIR}/XDC ]; then
    if [ ! -f apothem.tar ]; then
        echo
        wget -c -t 0 https://download.xinfin.network/snapshot/apothem.tar
    fi
    echo
    tar -xvf apothem.tar -C ${DATA_DIR}
fi

echo
${XDC} \
    --verbosity ${VERBOSITY} \
    --datadir ${DATA_DIR} \
    --networkid 51 \
    --etherbase 0x000000000000000000000000000000000000dead \
    --gcmode archive \
    --syncmode full \
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
    < /dev/null \
    >> "${LOG_FILE}" \
    2>&1 &

PID=$!
echo
echo "Sync PID = ${PID}"
echo "Log file = ${LOG_FILE}"
echo ${PID} > ${PID_FILE}
echo
