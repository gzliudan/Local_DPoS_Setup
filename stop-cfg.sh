#!/bin/bash
set -eo pipefail

function help() {
    echo
    echo "About:"
    echo "    This script stops one or more sync nodes by cfg."
    echo
    echo "Usage"
    echo "    $0 [options]"
    echo "    $0 <CFG> ..."
    echo
    echo "Options:"
    echo "    -h, --help     display this help"
    echo
    echo "Examples:"
    echo "    $0 8545.env"
    echo "    $0 8546.env 8547.env"
    echo
}

function stop_sync_by_cfg() {
    CFG_FILE="$1"
    CFG=$(basename ${CFG_FILE} .env)
    echo "handle CFG: ${CFG}"

    for PID_FILE in $(ls *-${CFG}-sync-*.pid 2>/dev/null); do
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
}

if [[ $# == 0 ]]; then
    help
    exit 1
fi

if [[ $# == 1 ]] && [[ "$1" == "-h" || "$1" == "--help" ]]; then
    help
    exit 0
fi

for arg in $@; do
    stop_sync_by_cfg ${arg}
done
