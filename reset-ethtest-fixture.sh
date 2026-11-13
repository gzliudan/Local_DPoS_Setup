#!/bin/bash
set -eo pipefail

# Wipe the ethtest fixture devnet data (nodes/ethtest-fixture) so the next
# run-ethtest-fixture.sh re-inits and re-imports from scratch.

FIXTURE_NODES_DIR="nodes/ethtest-fixture"

if [ -d "${FIXTURE_NODES_DIR}" ]; then
    echo "rm -rf ${FIXTURE_NODES_DIR}"
    rm -rf "${FIXTURE_NODES_DIR}"
else
    echo "nothing to reset: ${FIXTURE_NODES_DIR} does not exist"
fi
