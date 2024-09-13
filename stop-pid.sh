#!/bin/bash
set -eo pipefail

if [[ "$#" != 1 ]]; then
    echo "Usage: $0 <PID>"
    exit 1
fi

PID_FILE="$1"
if [[ ! -f "${PID_FILE}" ]]; then
    echo "Not find PID file: ${PID_FILE}"
    exit 2
fi

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
