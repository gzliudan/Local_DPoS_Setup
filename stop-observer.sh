#!/bin/bash
set -eo pipefail

function help() {
    echo
    echo "About:"
    echo "    This script stop an obsrever node for private network."
    echo
    echo "Usage:"
    echo "    $0 [options]"
    echo "    $0 [node_id]"
    echo
    echo "Examples:"
    echo "    $0 -h        Display this help messages"
    echo "    $0 --help    Display this help messages"
    echo "    $0 0         Stop an observer which id is 0"
    echo "    $0 1         Stop an observer which id is 1"
    echo
}

function stop_obsrever() {
    echo
    PID_FILE="$1"
    NODE_NAME=${PID_FILE%.*}

    if [ -f "${PID_FILE}" ]; then
        PID=$(cat ${PID_FILE})

        if [ -d "/proc/${PID}/fd" ]; then
            kill ${PID}
            echo -n "Stopping node ${NODE_NAME} ${PID} "
            while true; do
                echo -n "."
                [ ! -d "/proc/${PID}/fd" ] && echo && break
                sleep 1
            done
            echo "Node ${NODE_NAME} ${PID} is stopped"
        else
            echo "No such process: ${PID}"
        fi

        rm -f "${PID_FILE}"
    else
        echo "PID file is not existing: ${PID_FILE}"
    fi
}

if [[ $# == 1 ]] && [[ "$1" == "-h" || "$1" == "--help" ]]; then
    help
    exit 0
fi

if [ $# == 0 ]; then
    for PID_FILE in $(ls on*.pid 2>/dev/null); do
        stop_obsrever ${PID_FILE}
    done
else
    for arg in $@; do
        if [[ ${arg} =~ [^0-9] ]]; then
            echo "node_id ${arg} is not integer"
            exit 1
        fi
    done

    for arg in $@; do
        stop_obsrever "on${arg}.pid"
    done
fi

echo
echo "All obsrevers are stopped !"
echo
