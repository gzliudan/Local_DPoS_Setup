#!/bin/bash
_interupt() { 
    echo "Shutdown ${CHILD_PIDS}"
    kill -TERM ${CHILD_PIDS}
    exit
}

trap _interupt INT TERM

GAS_PRICE=1
VERBOSITY=3
NETWORK_ID=888
BASE_PORT=30000
BASE_RPC_PORT=8545
BASE_WS_RPC_PORT=9545

WORK_DIR=${PWD}
LOG_DIR="${WORK_DIR}/logs"
PROJECT_DIR="${HOME}/XDPoSChain"
XDC="${PROJECT_DIR}/build/bin/XDC"
GENESIS_FILE="${WORK_DIR}/genesis/XDPoS-3-signers.json"

touch .pwd
mkdir -p "${LOG_DIR}"
export $(cat .env | xargs)

# ENODE example: "enode://62457be5ca9c9ba3913d1513c22ca963b94548a7db06e7a629fec5b654ab7b09a704cba22229107b3f54848ae58e845dcce98393b48be619cc2860d56dd57198@127.0.0.1:30301"
echo -e "ENODE = ${ENODE}\n"

cd ${PROJECT_DIR} && make all
cd ${WORK_DIR}

echo -e "\nStarting the bootnode"
${PROJECT_DIR}/build/bin/bootnode -nodekey "${WORK_DIR}/bootnode.key" --addr 0.0.0.0:30301 > /dev/null 2>&1 &
CHILD_PIDS=$!

for NODE_ID in {0..3} ; do
  NODE_NAME="pn${NODE_ID}"
  echo -e "\nStarting the node ${NODE_ID}"

  PRIVATE_KEY="PRIVATE_KEY_${NODE_ID}"
  DATA_DIR="${WORK_DIR}/nodes/${NODE_NAME}"

  if [ ! -d "${DATA_DIR}/XDC/chaindata" ]; then
    WALLET=$(${XDC} account import --password .pwd --datadir ${DATA_DIR} <(echo ${!PRIVATE_KEY}) | awk -v FS="({|})" '{print $2}')
    ${XDC} --datadir ${DATA_DIR} init ${GENESIS_FILE}
  else
    WALLET=$(${XDC} account list --datadir ${DATA_DIR} | head -n 1 | awk -v FS="({|})" '{print $2}')
  fi

  echo "WALLET = ${WALLET}"
  echo "PRIVATE_KEY = ${!PRIVATE_KEY}" 

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
    --password "${WORK_DIR}/.pwd" \
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

  CHILD_PIDS="${CHILD_PIDS} $!"
done

echo ${CHILD_PIDS} > "${WORK_DIR}/private-networks.pid"

echo -e "\nPIDs = ${CHILD_PIDS}\n"

