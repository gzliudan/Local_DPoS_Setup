PID=$(cat apothem-snapshot.pid)
echo "stop sync process: ${PID}"
kill ${PID}
rm -f apothem-snapshot.pid
