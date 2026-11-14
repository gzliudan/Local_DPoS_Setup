#!/bin/bash
set -eo pipefail

# Bring up a devnet on the ethtest fixture chain (XDPoSChain repo,
# cmd/devp2p/internal/ethtest/testdata/xdc) for the #2968 regression:
#
#   frozen     - full node without masternode keys. Serves the imported
#                600-block chain to the suite; its head keeps moving as the
#                validators' blocks arrive through the fetcher.
#   validatorN - masternode nodes that continue mining past the imported
#                head. Three of the fixture's four masternodes must be online
#                for a QC quorum (ceil(2*4/3) = 3 signatures); a lone
#                validator can never advance the round. Their first block
#                import flips the frozen node's acceptTxs gate, which the
#                tx-facing suite cases need.
#
# All nodes share the exact chain the suite loads: same fixture genesis,
# same chain.rlp. Full static-peer mesh, discovery off, loopback RPC.

function help() {
    echo
    echo "About:"
    echo "    Start the ethtest fixture devnet (suite target + ${VALIDATOR_COUNT} validators for QC quorum)."
    echo
    echo "Usage:"
    echo "    $0"
    echo
    echo "Environment:"
    echo "    XDC               path to the XDC binary  (default: ~/XDPoSChain/build/bin/XDC)"
    echo "    FIXTURE_DIR       fixture chain directory (default: ~/XDPoSChain/cmd/devp2p/internal/ethtest/testdata/xdc)"
    echo "    ETHTEST_VALIDATORS  number of validators to start (default: 3; fixture has 4 masternodes)"
    echo "    ETHTEST_FROZEN_PORT / ETHTEST_FROZEN_RPC_PORT       (default: 30360 / 8625)"
    echo "    ETHTEST_VALIDATOR_BASE_PORT / ETHTEST_VALIDATOR_BASE_RPC_PORT (default: 30361 / 8626)"
    echo "    ETHTEST_MINER_GASPRICE  validator miner price (default 1000000000000 wei; keeps fixture txs out of blocks so their broadcast stays observable)"
    echo
}

if [[ $# == 1 ]] && [[ "$1" == "-h" || "$1" == "--help" ]]; then
    help
    exit 0
fi

if [ -f .env ]; then
    set -a
    # shellcheck disable=SC1091
    . ./.env
    set +a
fi

XDC_BIN="${XDC:-${HOME}/XDPoSChain/build/bin/XDC}"
BOOTNODE_BIN_FILE="${XDC_BIN%/*}/bootnode"
FIXTURE_DIR="${FIXTURE_DIR:-${HOME}/XDPoSChain/cmd/devp2p/internal/ethtest/testdata/xdc}"

for FILE in \
    "${XDC_BIN}" \
    "${BOOTNODE_BIN_FILE}" \
    "${FIXTURE_DIR}/genesis.json" \
    "${FIXTURE_DIR}/chain.rlp" \
    "${FIXTURE_DIR}/fixture-keys.json"
do
    if [ ! -f "${FILE}" ]; then
        echo "missing required file: ${FILE}"
        exit 1
    fi
done

# The suite sends the fixture chain id in Status and the node rejects any
# mismatch, so every node must run with exactly this network id.
NETWORK_ID=5152

VALIDATOR_COUNT="${ETHTEST_VALIDATORS:-3}"

FROZEN_PORT="${ETHTEST_FROZEN_PORT:-30360}"
FROZEN_RPC_PORT="${ETHTEST_FROZEN_RPC_PORT:-8625}"
VALIDATOR_BASE_PORT="${ETHTEST_VALIDATOR_BASE_PORT:-30361}"
VALIDATOR_BASE_RPC_PORT="${ETHTEST_VALIDATOR_BASE_RPC_PORT:-8626}"

FIXTURE_NODES_DIR="nodes/ethtest-fixture"
FROZEN_DIR="${FIXTURE_NODES_DIR}/frozen"

IMPORTED_HEAD=600
READY_TIMEOUT=300

DATE=$(date +%Y%m%d-%H%M%S)
LOG_DIR="${LOG_DIR:-logs}"
VERBOSITY="${VERBOSITY:-3}"
MINER_GAS_PRICE="${ETHTEST_MINER_GASPRICE:-1000000000000}"

function validator_name() {
    echo "validator$1"
}

function validator_dir() {
    echo "${FIXTURE_NODES_DIR}/$(validator_name "$1")"
}

function validator_port() {
    echo $((VALIDATOR_BASE_PORT + $1 - 1))
}

function validator_rpc_port() {
    echo $((VALIDATOR_BASE_RPC_PORT + $1 - 1))
}

function ensure_node_key() {
    DATA_DIR=$1
    NODE_KEY_FILE="${DATA_DIR}/XDC/nodekey"
    if [ ! -f "${NODE_KEY_FILE}" ]; then
        mkdir -p "${DATA_DIR}/XDC"
        ${BOOTNODE_BIN_FILE} -genkey "${NODE_KEY_FILE}"
    fi
}

function node_enode() {
    DATA_DIR=$1
    NODE_PORT=$2
    PUBKEY="$(${BOOTNODE_BIN_FILE} -nodekey "${DATA_DIR}/XDC/nodekey" -writeaddress)"
    echo "enode://${PUBKEY}@127.0.0.1:${NODE_PORT}"
}

function write_static_nodes_config() {
    DATA_DIR=$1
    shift
    mkdir -p "${DATA_DIR}/XDC"
    {
        echo "[Node.P2P]"
        echo "StaticNodes = ["
        for PEER_ENODE in "$@"; do
            echo "  \"${PEER_ENODE}\","
        done
        echo "]"
    } >"${DATA_DIR}/XDC/config.toml"
}

function init_and_import() {
    NAME=$1
    DATA_DIR=$2
    if [ -d "${DATA_DIR}/XDC/chaindata" ]; then
        echo "${NAME}: chaindata exists, skip init and import"
        return
    fi
    echo "${NAME}: init fixture genesis"
    ${XDC_BIN} init --datadir "${DATA_DIR}" "${FIXTURE_DIR}/genesis.json"
    echo "${NAME}: import chain.rlp"
    ${XDC_BIN} import --datadir "${DATA_DIR}" "${FIXTURE_DIR}/chain.rlp"
}

function validator_priv_key() {
    # Nth masternode key from the fixture key set (format owned by mkchain-xdc.sh).
    # XDC account import takes the raw hex: no 0x prefix, no trailing newline.
    INDEX=$1
    python3 - "${FIXTURE_DIR}/fixture-keys.json" "${INDEX}" <<'PYEOF'
import json, sys
with open(sys.argv[1]) as f:
    masternodes = list(json.load(f)["masternodes"].values())
key = masternodes[int(sys.argv[2]) - 1]["key"]
sys.stdout.write(key[2:] if key.startswith("0x") else key)
PYEOF
}

function start_frozen() {
    echo "Starting the node frozen (suite target)"
    nohup "${XDC_BIN}" \
        --config "${FROZEN_DIR}/XDC/config.toml" \
        --syncmode full \
        --gcmode archive \
        --datadir "${FROZEN_DIR}" \
        --networkid "${NETWORK_ID}" \
        --nodiscover \
        --verbosity "${VERBOSITY}" \
        --port "${FROZEN_PORT}" \
        --rpc \
        --rpcaddr "127.0.0.1" \
        --rpcport "${FROZEN_RPC_PORT}" \
        --rpcapi admin,eth,debug,net,rpc,txpool,web3 \
        >"${LOG_DIR}/ethtest-fixture-frozen-${DATE}.log" 2>&1 &
    echo $! >"${FIXTURE_NODES_DIR}/frozen.pid"
    node_enode "${FROZEN_DIR}" "${FROZEN_PORT}" >"${FIXTURE_NODES_DIR}/frozen.enode"
    echo "node frozen is running now, PID = $(cat "${FIXTURE_NODES_DIR}/frozen.pid")"
}

function start_validator() {
    INDEX=$1
    NAME=$(validator_name "${INDEX}")
    DATA_DIR=$(validator_dir "${INDEX}")

    echo "Starting the node ${NAME} (mining peer)"
    # XDC init creates an empty keystore directory, so the account must be
    # detected by listing, not by the directory's existence.
    WALLET=$(${XDC_BIN} account list --datadir "${DATA_DIR}" 2>/dev/null | head -n 1 | awk -v FS="({|})" '{print $2}')
    if [ -z "${WALLET}" ]; then
        ${XDC_BIN} account import --password .pwd --datadir "${DATA_DIR}" \
            <(validator_priv_key "${INDEX}")
        WALLET=$(${XDC_BIN} account list --datadir "${DATA_DIR}" | head -n 1 | awk -v FS="({|})" '{print $2}')
    fi
    if [ "${WALLET:0:3}" = "xdc" ]; then
        WALLET=${WALLET:3}
    fi
    if [ "${WALLET:0:2}" != "0x" ]; then
        WALLET="0x${WALLET}"
    fi
    echo "  WALLET = ${WALLET}"

    nohup "${XDC_BIN}" \
        --config "${DATA_DIR}/XDC/config.toml" \
        --syncmode full \
        --gcmode archive \
        --datadir "${DATA_DIR}" \
        --networkid "${NETWORK_ID}" \
        --nodiscover \
        --verbosity "${VERBOSITY}" \
        --port "$(validator_port "${INDEX}")" \
        --miner-gasprice "${MINER_GAS_PRICE}" \
        --password .pwd \
        --unlock "${WALLET}" \
        --rpc \
        --rpcaddr "127.0.0.1" \
        --rpcport "$(validator_rpc_port "${INDEX}")" \
        --rpcapi admin,eth,debug,miner,net,rpc,txpool,web3,XDPoS \
        >"${LOG_DIR}/ethtest-fixture-${NAME}-${DATE}.log" 2>&1 &
    echo $! >"${FIXTURE_NODES_DIR}/${NAME}.pid"
    echo "node ${NAME} is running now, PID = $(cat "${FIXTURE_NODES_DIR}/${NAME}.pid")"
}

# The frozen node's acceptTxs gate flips on its first fetcher import, i.e. on
# the validators' first block past the imported head. Suite tx-facing cases
# need that gate open, so wait until the frozen head passes the import point.
function wait_frozen_ready() {
    echo "waiting for the frozen node head to pass block ${IMPORTED_HEAD} (timeout ${READY_TIMEOUT}s)"
    DEADLINE=$((SECONDS + READY_TIMEOUT))
    while true; do
        RESULT=$(curl -s --max-time 3 -X POST -H 'Content-Type: application/json' \
            --data '{"jsonrpc":"2.0","method":"eth_blockNumber","params":[],"id":1}' \
            "http://127.0.0.1:${FROZEN_RPC_PORT}" || true)
        HEAD_HEX=$(printf '%s' "${RESULT}" | sed -n 's/.*"result":"0x\([0-9a-fA-F]*\)".*/\1/p')
        if [ -n "${HEAD_HEX}" ]; then
            HEAD_DEC=$((16#${HEAD_HEX}))
            if [ "${HEAD_DEC}" -gt "${IMPORTED_HEAD}" ]; then
                echo "frozen node head = ${HEAD_DEC}, acceptTxs gate is open"
                return 0
            fi
            echo "frozen node head = ${HEAD_DEC}"
        fi
        for PID_FILE in "${FIXTURE_NODES_DIR}"/validator*.pid; do
            if [ -f "${PID_FILE}" ]; then
                PID=$(cat "${PID_FILE}")
                if [ ! -d "/proc/${PID}/fd" ]; then
                    echo "validator process ${PID} (${PID_FILE}) died; check ${LOG_DIR}/ethtest-fixture-*-validator log"
                    exit 5
                fi
            fi
        done
        if [ "${SECONDS}" -ge "${DEADLINE}" ]; then
            echo "timeout waiting for the frozen node to advance past block ${IMPORTED_HEAD};"
            echo "check ${LOG_DIR}/ethtest-fixture-validator*-*.log for quorum and staking issues"
            exit 5
        fi
        sleep 2
    done
}

touch .pwd
mkdir -p "${LOG_DIR}"

# All node keys first, so every config can reference every other node's enode.
ensure_node_key "${FROZEN_DIR}"
for i in $(seq 1 "${VALIDATOR_COUNT}"); do
    ensure_node_key "$(validator_dir "${i}")"
done

FROZEN_ENODE=$(node_enode "${FROZEN_DIR}" "${FROZEN_PORT}")
declare -a VALIDATOR_ENODES=()
for i in $(seq 1 "${VALIDATOR_COUNT}"); do
    VALIDATOR_ENODES+=("$(node_enode "$(validator_dir "${i}")" "$(validator_port "${i}")")")
done

# Full mesh: the validators must reach each other to collect QC/TC signatures.
write_static_nodes_config "${FROZEN_DIR}" "${VALIDATOR_ENODES[@]}"
for i in $(seq 1 "${VALIDATOR_COUNT}"); do
    PEERS=("${FROZEN_ENODE}")
    for j in $(seq 1 "${VALIDATOR_COUNT}"); do
        if [ "${i}" != "${j}" ]; then
            PEERS+=("${VALIDATOR_ENODES[$((j - 1))]}")
        fi
    done
    write_static_nodes_config "$(validator_dir "${i}")" "${PEERS[@]}"
done

for i in $(seq 1 "${VALIDATOR_COUNT}"); do
    init_and_import "$(validator_name "${i}")" "$(validator_dir "${i}")"
done
init_and_import frozen "${FROZEN_DIR}"

for PID_FILE in "${FIXTURE_NODES_DIR}"/*.pid; do
    if [ -f "${PID_FILE}" ]; then
        OLD_PID=$(cat "${PID_FILE}")
        if [ -d "/proc/${OLD_PID}/fd" ]; then
            echo "a fixture node is already running (PID ${OLD_PID}, ${PID_FILE}); stop it first: ./stop-ethtest-fixture.sh"
            exit 3
        fi
    fi
done

start_frozen
for i in $(seq 1 "${VALIDATOR_COUNT}"); do
    start_validator "${i}"
done

wait_frozen_ready

echo
echo "fixture devnet is ready:"
echo "  suite target enode : $(cat "${FIXTURE_NODES_DIR}/frozen.enode")"
echo "  frozen RPC         : http://127.0.0.1:${FROZEN_RPC_PORT}"
for i in $(seq 1 "${VALIDATOR_COUNT}"); do
    echo "  validator${i} RPC      : http://127.0.0.1:$(validator_rpc_port "${i}")"
done
echo "  run the suite      : ./run-ethtest-suite.sh"
