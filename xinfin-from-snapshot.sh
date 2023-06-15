#!/bin/bash
set -eo pipefail

VERBOSITY=3
NETWORK="xinfin"
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
    wget https://raw.githubusercontent.com/XinFinOrg/XinFin-Node/master/mainnet/genesis.json -O genesis-${NETWORK}.json
fi

if [ ! -d ${DATA_DIR}/keystore ]; then
    echo
    echo "init data dir: ${DATA_DIR}"
    ${XDC} --datadir ${DATA_DIR} init genesis-${NETWORK}.json
    mv ${DATA_DIR}/XDC ${DATA_DIR}/XDC.bak
fi

if [ ! -d ${DATA_DIR}/XDC ]; then
    if [ ! -f xdcchain.tar ]; then
        echo
        wget -c -t 0 https://download.xinfin.network/xdcchain.tar
    fi
    echo
    tar -xvf xdcchain.tar -C ${DATA_DIR}
fi

echo
${XDC} \
    --verbosity ${VERBOSITY} \
    --datadir ${DATA_DIR} \
    --networkid 50 \
    --etherbase 0x000000000000000000000000000000000000dead \
    --gcmode archive \
    --syncmode full \
    --skip-signers \
    < /dev/null \
    >> "${LOG_FILE}" \
    2>&1 &

PID=$!
echo
echo "Sync PID = ${PID}"
echo "Log file = ${LOG_FILE}"
echo ${PID} > ${PID_FILE}
echo