#!/bin/bash
set -eo pipefail

# Run the full ethtest registry against the fixture devnet's frozen node
# (the #2968 regression). Requires run-ethtest-fixture.sh to have completed.

if [ -f .env ]; then
    set -a
    # shellcheck disable=SC1091
    . ./.env
    set +a
fi

DEVP2P_BIN="${DEVP2P:-${HOME}/XDPoSChain/build/bin/devp2p}"
FIXTURE_DIR="${FIXTURE_DIR:-${HOME}/XDPoSChain/cmd/devp2p/internal/ethtest/testdata/xdc}"
ENODE_FILE="nodes/ethtest-fixture/frozen.enode"

if [ ! -f "${DEVP2P_BIN}" ]; then
    echo "missing devp2p binary: ${DEVP2P_BIN}"
    exit 1
fi
if [ ! -f "${ENODE_FILE}" ]; then
    echo "missing ${ENODE_FILE}; run ./run-ethtest-fixture.sh first"
    exit 1
fi

ENODE=$(cat "${ENODE_FILE}")
mkdir -p "${LOG_DIR:-logs}"
LOG_FILE="${LOG_DIR:-logs}/ethtest-suite-$(date +%Y%m%d-%H%M%S).log"

echo "suite target: ${ENODE}"
echo "fixture dir : ${FIXTURE_DIR}"
echo "log file    : ${LOG_FILE}"
echo

# --tap prints one ok/not-ok line per case; pipefail keeps the suite's exit
# code through tee.
"${DEVP2P_BIN}" rlpx eth-test --node "${ENODE}" --chain "${FIXTURE_DIR}" --tap 2>&1 | tee "${LOG_FILE}"
