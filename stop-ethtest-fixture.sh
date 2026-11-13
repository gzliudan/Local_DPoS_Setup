#!/bin/bash
set -eo pipefail

# Stop the two-node ethtest fixture devnet started by run-ethtest-fixture.sh.

FIXTURE_NODES_DIR="nodes/ethtest-fixture"

function stop_node() {
    PID_FILE=$1
    NAME=${PID_FILE##*/}

    if [ ! -f "${PID_FILE}" ]; then
        echo "no pid file for ${NAME}"
        return
    fi

    PID=$(cat "${PID_FILE}")
    if [ -d "/proc/${PID}/fd" ]; then
        kill "${PID}"
        echo -n "Stopping node ${NAME} ${PID} "
        while true; do
            echo -n "."
            [ ! -d "/proc/${PID}/fd" ] && echo && break
            sleep 1
        done
        echo "Node ${NAME} ${PID} is stopped"
    else
        echo "No such process for ${NAME}: ${PID}"
    fi

    rm -f "${PID_FILE}"
}

shopt -s nullglob
for PID_FILE in "${FIXTURE_NODES_DIR}"/*.pid; do
    stop_node "${PID_FILE}"
done
shopt -u nullglob

echo
echo "All fixture nodes are stopped !"
