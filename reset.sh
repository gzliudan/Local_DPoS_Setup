#!/bin/bash
set -eo pipefail


function help() {
    echo
    echo "About:"
    echo "    This script delete directories nodes and logs under ${PWD}"
    echo
    echo "Usage:"
    echo "    $0 [options]"
    echo
    echo "Options:"
    echo "    -f, --force    delete data at once without confirmation"
    echo "    -h, --help     display this help messages"
    echo
}


function confirm() {
    read -p "$1 [Yes/No]: " yes_or_no

    case ${yes_or_no} in
        [Yy][Ee][Ss]|Y|y)
            echo "Yes"
            ;;
        [Nn][Oo]|N|n)
            echo "No"
            ;;
        *)
            echo "Other"
            ;;
    esac    
}


function delete_all() {
    echo "rm -rf nodes logs"
    rm -rf nodes logs
}


function execute_wizard() {
    echo "Do you want to delete directories nodes and logs ?"

    PS3="Please input a number: "
    select choice in "Delete" "Quit"; do
        case ${choice} in
            "Delete" )
                break
                ;;
            * )
                echo "Quit"
                return 1
                ;;
        esac
    done    

    answer=$(confirm "Do you want to delete all data ?")

    if [ "${answer}" = "Yes" ]; then
        delete_all
    else
        echo "Abort"
        return 2
    fi
}


if [ $# == 0 ] ; then
    execute_wizard
elif [ $# == 1 ] ; then
    if [[ "$1" == "-h" || "$1" == "--help" ]]; then
        help
        exit 0
    elif [[ "$1" == "-f" || "$1" == "--force" ]]; then
        delete_all
    else
        help
        exit 3
    fi
else
    help
    exit 3
fi
