#!/bin/bash
set -eo pipefail


function help() {
    echo
    echo "About:"
    echo "    This script stop one or more node in private network."
    echo
    echo "Usage:"
    echo "    $0 [node_id] ..."
    echo
    echo "Examples:"
    echo "    $0            Stop all nodes without node_id"
    echo "    $0 0          Stop 1 node which node_id is 0"
    echo "    $0 2 3        Stop 2 nodes which node_id are 2, 3"
    echo "    $0 1 2 3      Stop 3 nodes which node_id are 1, 2, 3"
    echo "    $0 0 1 2 3    Stop 4 nodes which node_id are 0, 1, 2, 3"
    echo "    $0 -h         Display this help messages"
    echo "    $0 --help     Display this help messages"
    echo
}


function stop_node() {
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

echo
echo "All nodes are stopped !"
echo
