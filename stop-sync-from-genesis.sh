PID=$(cat apothem-genesis.pid)
echo "stop sync process: ${PID}"
kill ${PID}
rm -f apothem-genesis.pid
