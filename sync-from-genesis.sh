#!/bin/bash
set -eo pipefail

VERBOSITY=3
DATA_DIR="${HOME}/.apothem"
LOG_DIR="${HOME}/sync/apothem"

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
echo ${PID} > apothem-genesis.pid
