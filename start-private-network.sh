#!/bin/bash
set -eo pipefail


function help() {
    echo
    echo "About:"
    echo "    This script start one or more node in private network."
    echo
    echo "Usage"
    echo "    $0 [options]"
    echo "    $0 <node_id> ..."
    echo
    echo "Options:"
    echo "    -h, --help     display this help"
    echo
    echo "Examples:"
    echo "    $0 0          Start 1 node which node_id is 0"
    echo "    $0 2 3        Start 3 nodes which node_id are 2, 3"
    echo "    $0 1 2 3      Start 3 nodes which node_id are 0, 1, 2"
    echo "    $0 0 1 2 3    Start 4 nodes which node_id are 0, 1, 2, 3"
    echo "    $0 -h         Display this help messages"
    echo "    $0 --help     Display this help messages"
    echo
}


if [ $# == 0 ] ; then
    help
    exit 1
fi

if [[ $# == 1 ]] && [[ "$1" == "-h" || "$1" == "--help" ]]; then
    help
    exit 0
fi

for arg in $@; do
    if [[ ${arg} =~ [^0-9] ]] ; then
        echo "node_id ${arg} is not integer"
        exit 2
    fi

    NODE_NAME="pn${arg}"
    PID_FILE="${NODE_NAME}.pid"
    if [ -f "${PID_FILE}" ] ; then
        PID=$(cat "${PID_FILE}")
        if [ -d "/proc/${PID}/fd" ]; then
            echo "please stop node ${NODE_NAME}[${PID}] first: found file ${PID_FILE}"
            exit 3
        fi
    fi
done


# Logging verbosity: 0=silent, 1=error, 2=warn, 3=info, 4=debug, 5=detail (default: 3)
VERBOSITY=4
GAS_PRICE=1
NETWORK_ID=888
BASE_PORT=30000
BASE_RPC_PORT=8545
BASE_WS_RPC_PORT=9545
DATE=$(date +%Y%m%d-%H%M%S)

WORK_DIR=${PWD}
LOG_DIR="logs"
PROJECT_DIR="${HOME}/XDPoSChain"
BOOTNODE_PID_FILE="bootnode.pid"
XDC="${PROJECT_DIR}/build/bin/XDC"


function set_enode() {
    if [ ! -f bootnode.key ]; then
        echo "create bootnode.key"
        ${PROJECT_DIR}/build/bin/bootnode -genkey bootnode.key
    fi

    if [ ! -f bootnode.txt ]; then
        echo "create bootnode.txt"
        ${PROJECT_DIR}/build/bin/bootnode -nodekey bootnode.key > bootnode.txt 2>&1 &
        PID=$!
        sleep 1
        kill $PID 
    fi

    # ENODE="enode://62457be5ca9c9ba3913d1513c22ca963b94548a7db06e7a629fec5b654ab7b09a704cba22229107b3f54848ae58e845dcce98393b48be619cc2860d56dd57198@127.0.0.1:30301"
    ENODE="$(grep -Eo 'enode://[0-9a-f]*' bootnode.txt)@127.0.0.1:30301"
}


function start_bootnode() {
    echo "Starting the bootnode"
    ${PROJECT_DIR}/build/bin/bootnode -nodekey bootnode.key --addr 0.0.0.0:30301 > /dev/null 2>&1 &
    PID=$!
    echo ${PID} > ${BOOTNODE_PID_FILE}
    echo "bootnode is running now: ${PID}"
}


function start_node() {
    NODE_ID=$1
    NODE_NAME="pn${NODE_ID}"
    PID_FILE="${NODE_NAME}.pid"
    DATA_DIR="nodes/${NODE_NAME}"

    echo "Starting the node ${NODE_ID}"

    if [ ! -d "${DATA_DIR}/XDC/chaindata" ]; then
        PRIVATE_KEY_NAME="PRIVATE_KEY_${NODE_ID}"
        PRIVATE_KEY="${!PRIVATE_KEY_NAME}"
        if [[ ${#PRIVATE_KEY} -eq 66 && ( ${PRIVATE_KEY:0:2} = "0x" || ${PRIVATE_KEY:0:2} = "0X" ) ]]; then
            PRIVATE_KEY=${PRIVATE_KEY:2}
        fi
        if [[ ${#PRIVATE_KEY} != 64 || ${PRIVATE_KEY} =~ [^0-9a-fA-F] ]]; then
            echo "${PRIVATE_KEY_NAME} is invalid: ${PRIVATE_KEY}"
            exit 4
        fi

        WALLET=$(${XDC} account import --password .pwd --datadir ${DATA_DIR} <(echo ${PRIVATE_KEY}) | awk -v FS="({|})" '{print $2}')
        if [ ! -f genesis.json ]; then
            cp genesis/XDPoS-3-signers.json genesis.json
        fi
        ${XDC} --datadir ${DATA_DIR} init genesis.json
    else
        WALLET=$(${XDC} account list --datadir ${DATA_DIR} | head -n 1 | awk -v FS="({|})" '{print $2}')
    fi

    if [ ${WALLET:0:3} = "xdc" ]; then
        WALLET=${WALLET:3}
    fi

    if [ ${WALLET:0:2} != "0x" ]; then
        WALLET="0x${WALLET}"
    fi

    echo "WALLET = ${WALLET}"

    PORT=$((${BASE_PORT}+${NODE_ID}))
    RPC_PORT=$((${BASE_RPC_PORT}+${NODE_ID}))
    WS_RPC_PORT=$((${BASE_WS_RPC_PORT}+${NODE_ID}))

    ${XDC} \
        --mine \
        --gcmode archive \
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
        > "${LOG_DIR}/${NODE_NAME}-${DATE}.log" 2>&1 &

    PID=$!
    echo ${PID} > ${PID_FILE}
    echo "node is running now: ${PID}"
    echo
}


echo
cd ${PROJECT_DIR}
make all
cd ${WORK_DIR}

echo
set_enode
echo "ENODE = ${ENODE}"

echo
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

echo
touch .pwd
mkdir -p "${LOG_DIR}"
export $(cat .env | xargs)
for arg in $@; do
    start_node ${arg}
done
