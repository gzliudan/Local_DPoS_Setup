#!/bin/bash
set -eo pipefail

for PID_FILE in $(ls *-sync.pid 2> /dev/null); do
    PID=$(cat ${PID_FILE})

    if [ -d "/proc/${PID}/fd" ]; then
        echo "Stopping sync process: ${PID}"
        kill ${PID}
    else
        echo "No such process: ${PID}"
    fi

    rm -f "${PID_FILE}"
done
