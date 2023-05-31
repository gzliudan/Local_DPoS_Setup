#!/bin/bash
set -eo pipefail


function help() {
    echo "Usage: $0 <node_id> ..."
    echo "Examples:"
    echo "Stop all nodes: $0"
    echo "Stop  1  node : $0 0"
    echo "Stop  2  nodes: $0 2 3"
    echo "Stop  3  nodes: $0 1 2 3"
    echo "Stop  4  nodes: $0 0 1 2 3"
}


function stop_node() {
    PID_FILE="$1"    

    if [ -f "${PID_FILE}" ]; then
        PID=$(cat ${PID_FILE})

        if [ -d "/proc/${PID}/fd" ]; then
            echo "Stopping node pn${PID} ..."
            kill ${PID}
        else
            echo "No such process: ${PID}"
        fi

        rm -f "${PID_FILE}"
    else
        echo "PID file is not existing: ${PID_FILE}"
    fi
}


if [[ "$1" == "-h" || "$1" == "--help" ]]; then
    help
    exit 0
fi

if [ $# == 0 ] ; then
    for PID_FILE in $(ls pn*.pid 2> /dev/null); do
        stop_node ${PID_FILE}
    done
else
    for arg in $@; do
        if [[ ${arg} =~ [^0-9] ]] ; then
            echo "node_id ${arg} is not integer"
            exit 2
        fi
    done

    for arg in $@; do
        stop_node "pn${arg}.pid"
    done
fi
