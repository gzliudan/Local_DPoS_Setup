#!/bin/bash
set -eo pipefail

VERBOSITY=3
DATA_DIR="${HOME}/.testnet"
LOG_DIR="${HOME}/sync/testnet"

cd ${HOME}
if [ ! -d XDPoSChain ]; then
    git clone https://github.com/XinFinOrg/XDPoSChain.git
fi
cd XDPoSChain
make all

mkdir -p ${LOG_DIR}
cd ${HOME}/sync/

if [ ! -f apothem.json ]; then
    wget https://raw.githubusercontent.com/XinFinOrg/Local_DPoS_Setup/apothem/genesis/genesis.json -O apothem.json
fi

if [ ! -d ${DATA_DIR}/keystore ]; then
    ${HOME}/XDPoSChain/build/bin/XDC --datadir ${DATA_DIR} init --apothem
    mv ${DATA_DIR}/XDC ${DATA_DIR}/XDC.bak
fi

if [ ! -d ${DATA_DIR}/XDC ]; then
    if [ ! -f apothem.tar ]; then
        wget -c -t 0 https://download.xinfin.network/apothem.tar
    fi
    tar -xvf apothem.tar -C ${DATA_DIR}
fi

${HOME}/XDPoSChain/build/bin/XDC \
    --verbosity ${VERBOSITY} \
    --datadir ${DATA_DIR} \
    --networkid 51 \
    --etherbase 0x000000000000000000000000000000000000dead \
    --gcmode archive \
    --syncmode full \
    < /dev/null \
    > "${LOG_DIR}/apothem-$(date +%Y%m%d-%H%M%S).log" \
    2>&1 &

PID=$!
echo ${PID} > apothem-snapshot.pid
