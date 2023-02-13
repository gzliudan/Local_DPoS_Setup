#!/bin/bash
_interupt() { 
    echo "Shutdown $child_proc"
    kill -TERM $child_proc
    exit
}

trap _interupt INT TERM

touch .pwd
export $(cat .env | xargs)
Bin_NAME=XDC

WORK_DIR=$PWD
PROJECT_DIR="${HOME}/XDPoSChain"

# compile XDPoSChain project
if [ ! -d ${PROJECT_DIR} ]; then
  git clone https://github.com/XinFinOrg/XDPoSChain ${PROJECT_DIR}
  git checkout apothem
fi
cd ${PROJECT_DIR}
make all

# download apothem snapshot
if [ -f "${HOME}/apothem.tar" ]; then
  echo "Skip download snapshot"
else
  echo "Download snapshot OK"
  wget -c -t 0 https://download.xinfin.network/apothem.tar -O "${HOME}/apothem.tar"
  if [ $? -eq 0 ]; then
    echo "Download snapshot OK"
  else
    echo "Fail to download snapshot"
    exit 1
  fi
fi

NODE_ID=snap1
DATA_DIR="${WORK_DIR}/nodes/${NODE_ID}"

cd $WORK_DIR
if [ ! -d "${DATA_DIR}/keystore" ]; then
  wallet1=$(${PROJECT_DIR}/build/bin/$Bin_NAME account import --password .pwd --datadir ${DATA_DIR} <(echo ${PRIVATE_KEY_1}) | awk -v FS="({|})" '{print $2}')
  
  # init datadir
  ${PROJECT_DIR}/build/bin/$Bin_NAME --datadir ${DATA_DIR} init ./genesis/genesis.json

  # unzip snapshot
  if [ -d "${HOME}/XDC" ]; then
    echo "Skip unizp snapshot"
  else
    echo "Unzip snapshot"
    tar -xzf ${HOME}/apothem.tar -C ${HOME}
    if [ $? -eq 0 ]; then
      echo "Unzip snapshot OK"
    else
      echo "Fail to unzip snapshot"
      rm -rf "${HOME}/XDC"
      exit 2
    fi
  fi

  # move snapshot
  for DIR in $(ls "${HOME}/XDC"); do 
    rm -rf "${DATA_DIR}/XDC/${DIR}" 
    mv "${HOME}/XDC/${DIR}" "${DATA_DIR}/XDC"
  done
else
  wallet1=$(${PROJECT_DIR}/build/bin/$Bin_NAME account list --datadir ${DATA_DIR} | head -n 1 | awk -v FS="({|})" '{print $2}')
fi

VERBOSITY=3
GASPRICE="1"
networkid=51
INSTANCE_IP=$(curl -s https://checkip.amazonaws.com)


echo Starting the bootnode ...
${PROJECT_DIR}/build/bin/bootnode -nodekey ./bootnode.key --addr 0.0.0.0:30301 &
child_proc=$! 

echo Starting the nodes ...
mkdir -p logs
${PROJECT_DIR}/build/bin/$Bin_NAME \
--gcmode=archive \
--store-reward \
--bootnodes "enode://1c20e6b46ce608c1fe739e78611225b94e663535b74a1545b1667eac8ff75ed43216306d123306c10e043f228e42cc53cb2728655019292380313393eaaf6e23@109.169.40.128:30301,enode://1c20e6b46ce608c1fe739e78611225b94e663535b74a1545b1667eac8ff75ed43216306d123306c10e043f228e42cc53cb2728655019292380313393eaaf6e23@188.227.164.51:30301,enode://ec569f5d52cefee5c5405a0c5db720dc7061f3085e0682dd8321413430ddda6a177b85db75b0daf83d2e68760ba3f5beb4ba9e333e7d52072fba4d39b05a0451@188.227.164.51:30301,enode://1c20e6b46ce608c1fe739e78611225b94e663535b74a1545b1667eac8ff75ed43216306d123306c10e043f228e42cc53cb2728655019292380313393eaaf6e23@188.227.164.51:30301,enode://1c20e6b46ce608c1fe739e78611225b94e663535b74a1545b1667eac8ff75ed43216306d123306c10e043f228e42cc53cb2728655019292380313393eaaf6e23@95.179.217.201:30301,enode://1c20e6b46ce608c1fe739e78611225b94e663535b74a1545b1667eac8ff75ed43216306d123306c10e043f228e42cc53cb2728655019292380313393eaaf6e23@149.28.167.190:30301,enode://1c20e6b46ce608c1fe739e78611225b94e663535b74a1545b1667eac8ff75ed43216306d123306c10e043f228e42cc53cb2728655019292380313393eaaf6e23@194.233.77.19:30301,enode://1c20e6b46ce608c1fe739e78611225b94e663535b74a1545b1667eac8ff75ed43216306d123306c10e043f228e42cc53cb2728655019292380313393eaaf6e23@144.91.108.231:30301,enode://1c20e6b46ce608c1fe739e78611225b94e663535b74a1545b1667eac8ff75ed43216306d123306c10e043f228e42cc53cb2728655019292380313393eaaf6e23@207.244.240.232:30301,enode://1c20e6b46ce608c1fe739e78611225b94e663535b74a1545b1667eac8ff75ed43216306d123306c10e043f228e42cc53cb2728655019292380313393eaaf6e23@66.94.121.62:30301,enode://1c20e6b46ce608c1fe739e78611225b94e663535b74a1545b1667eac8ff75ed43216306d123306c10e043f228e42cc53cb2728655019292380313393eaaf6e23@144.126.150.69:30301,enode://1c20e6b46ce608c1fe739e78611225b94e663535b74a1545b1667eac8ff75ed43216306d123306c10e043f228e42cc53cb2728655019292380313393eaaf6e23@161.97.93.168:30301" \
--syncmode "full" \
--datadir ${DATA_DIR} \
--apothem \
--networkid "${networkid}" \
--port 30303 \
--rpc \
--rpccorsdomain "*" \
--ws \
--wsaddr="0.0.0.0" \
--wsorigins "*" \
--wsport 8555 \
--rpcaddr 0.0.0.0 \
--rpcport 8545 \
--rpcvhosts "*" \
--unlock "${wallet1}" \
--password ./.pwd --mine \
--gasprice "${GASPRICE}" \
--targetgaslimit "420000000" \
--verbosity ${VERBOSITY} \
--rpcapi admin,db,eth,debug,miner,net,shh,txpool,personal,web3,XDPoS \
--ethstats "${wallet1}_${INSTANCE_IP}:xdc_xinfin_apothem_network_stats@stats.apothem.network:2000" \
> "./logs/${NODE_ID}-`date +%Y%m%d-%H%M%S`.log" 2>&1 &

child_proc="$child_proc $!"

echo ${child_proc} > "${WORK_DIR}/sync-from-snap.pid"

sleep 3
cat "${WORK_DIR}/sync-from-snap.pid"
