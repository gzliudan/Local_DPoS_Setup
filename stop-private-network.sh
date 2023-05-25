#!/bin/bash
set -eo pipefail

if [ $# == 0 ] ; then
    echo "Usage: $0 node_id ..."
    echo "Examples:"
    echo "$0 0"
    echo "$0 2"
    echo "$0 0 1"
    echo "$0 2 3"
    echo "$0 0 1 2"
    echo "$0 0 1 2 3"
    exit 1
fi

for arg in $@; do
    if [[ ${arg} =~ [^0-9] ]] ; then
        echo "node_id ${arg} is not integer"
        exit 2
    fi
done

for arg in $@; do
    PID_FILE="pn${arg}.pid"
    if [ -f "${PID_FILE}" ]; then
        PID=$(cat ${PID_FILE})
            if [ -d "/proc/${PID}/fd" ]; then
            kill ${PID}
            echo "Stopping node pn${PID} ..."
        else
            echo "No such process: ${PID}"
        fi
        rm -f ${PID_FILE}
    else
        echo "PID file is not existing: ${PID_FILE}"
    fi
done
