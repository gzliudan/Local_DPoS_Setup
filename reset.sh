#!/bin/bash
set -eo pipefail


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


echo "Which directory do you want to delete ?"

PS3="Please select a number: "
select DIR in "nodes logs" "nodes" "logs" "quit"; do
    case ${DIR} in
        "nodes logs"|"nodes"|"logs")
            break
            ;;
		*)
            echo "quit"
			exit 1
			;;
	esac
done    

answer=$(confirm "Remove direcotry ${DIR} ?")

if [ "${answer}" = "Yes" ]; then
    echo "rm -rf ${DIR}"
    rm -rf ${DIR}
else
    echo "abort"
    exit 2
fi
