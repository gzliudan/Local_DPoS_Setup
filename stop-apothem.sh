#!/bin/bash
set -eo pipefail

for PID_FILE in $(ls apothem-*-sync.pid 2> /dev/null); do
    PID=$(cat ${PID_FILE})

    if [ -d "/proc/${PID}/fd" ]; then
        kill ${PID}
        echo -n "Stopping the sync process: ${PID} "
        while true; do
            echo -n "."
            [ ! -d "/proc/${PID}/fd" ] && echo && break
            sleep 1
        done
        echo "The sync process ${PID} is stopped"
    else
        echo "No such process: ${PID}"
    fi

    rm -f "${PID_FILE}"
done
