#!/bin/bash
set -eo pipefail

if [ $# -ne 0 ]; then
    echo "Usage: $0"
    exit 1
fi

for PID_FILE in $(ls devnet*-sync.pid 2> /dev/null); do
    echo "Find PID_FILE: ${PID_FILE}"
    PID=$(cat ${PID_FILE})

    if [ -d "/proc/${PID}/fd" ]; then
        kill ${PID}
        echo -n "Stopping the process: ${PID} "
        while true; do
            echo -n "."
            [ ! -d "/proc/${PID}/fd" ] && echo && break
            sleep 1
        done
        echo "The process ${PID} is stopped"
    else
        echo "No such process: ${PID}"
    fi

    rm -f "${PID_FILE}"
done
