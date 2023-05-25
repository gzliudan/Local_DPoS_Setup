#!/bin/bash
set -eo pipefail

if [ $# == 0 ] ; then
    echo "Usage: $0 node_id ..."
    echo "Examples:"
    echo "$0 0"
    echo "$0 2"
    echo "$0 0 1"
    echo "$0 2 3"
    echo "$0 0 1 2"
    echo "$0 0 1 2 3"
    exit 1
fi

for arg in $@; do
    if [[ ${arg} =~ [^0-9] ]] ; then
        echo "node_id ${arg} is not integer"
        exit 2
    fi
done

# Logging verbosity: 0=silent, 1=error, 2=warn, 3=info, 4=debug, 5=detail (default: 3)
VERBOSITY=4
GAS_PRICE=1
NETWORK_ID=888
BASE_PORT=30000
BASE_RPC_PORT=8545
BASE_WS_RPC_PORT=9545

WORK_DIR=${PWD}
LOG_DIR="logs"
PROJECT_DIR="${HOME}/XDPoSChain"
BOOTNODE_PID_FILE="bootnode.pid"
XDC="${PROJECT_DIR}/build/bin/XDC"
ENODE="enode://62457be5ca9c9ba3913d1513c22ca963b94548a7db06e7a629fec5b654ab7b09a704cba22229107b3f54848ae58e845dcce98393b48be619cc2860d56dd57198@127.0.0.1:30301"

export $(cat .env | xargs)
echo "ENODE=${ENODE}"

function start_bootnode() {
    echo -e "\nStarting the bootnode"
    ${PROJECT_DIR}/build/bin/bootnode -nodekey bootnode.key --addr 0.0.0.0:30301 > /dev/null 2>&1 &
    PID=$!
    echo ${PID} > ${BOOTNODE_PID_FILE}
    echo "bootnode is running now: ${PID}"
}

function start_node() {
    NODE_ID=$1
    NODE_NAME="pn${NODE_ID}"
    echo -e "\nStarting the node ${NODE_ID}"

    PRIVATE_KEY="PRIVATE_KEY_${NODE_ID}"
    DATA_DIR="nodes/${NODE_NAME}"

    if [ ! -d "${DATA_DIR}/XDC/chaindata" ]; then
        WALLET=$(${XDC} account import --password .pwd --datadir ${DATA_DIR} <(echo ${!PRIVATE_KEY}) | awk -v FS="({|})" '{print $2}')
        if [ ! -f genesis.json ]; then
            cp genesis/XDPoS-3-signers.json genesis.json
        fi
        ${XDC} --datadir ${DATA_DIR} init genesis.json
    else
        WALLET=$(${XDC} account list --datadir ${DATA_DIR} | head -n 1 | awk -v FS="({|})" '{print $2}')
    fi

    echo "WALLET = ${WALLET}"

    PORT=$((${BASE_PORT}+${NODE_ID}))
    RPC_PORT=$((${BASE_RPC_PORT}+${NODE_ID}))
    WS_RPC_PORT=$((${BASE_WS_RPC_PORT}+${NODE_ID}))

    ${XDC} \
        --mine \
        --syncmode full \
        --enable-0x-prefix \
        --bootnodes ${ENODE} \
        --datadir ${DATA_DIR} \
        --networkid ${NETWORK_ID} \
        --verbosity ${VERBOSITY} \
        --gasprice ${GAS_PRICE} \
        --targetgaslimit 420000000 \
        --password .pwd \
        --unlock "${WALLET}" \
        --port ${PORT} \
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
        > "${LOG_DIR}/${NODE_NAME}-$(date +%Y%m%d-%H%M%S).log" 2>&1 &

    PID=$!
    echo ${PID} > ${NODE_NAME}.pid
    echo "node is running now: ${PID}"
}

cd ${PROJECT_DIR} && make all
cd ${WORK_DIR}

touch .pwd
mkdir -p "${LOG_DIR}"

if [ -f ${BOOTNODE_PID_FILE} ]; then
    PID=$(cat ${BOOTNODE_PID_FILE})
        if [ -d "/proc/${PID}/fd" ]; then
        echo "bootnode is already running: ${PID}"
    else
        start_bootnode
    fi
else
    start_bootnode
fi

for arg in $@; do
    start_node ${arg}
done
