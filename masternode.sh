#!/bin/bash
RED='\033[0;31m'
GREEN='\033[0;32m'
CYAN='\033[0;36m'
YELLOW='\e[1;33m'
NC='\033[0m' # No Color

LOCAL_IP=$(ifconfig | grep -Eo 'inet (addr:)?([0-9]*\.){3}[0-9]*' | grep -Eo '([0-9]*\.){3}[0-9]*' | grep -v '127.0.0.1')

function readJsonValue {
  LINE=`grep -m 1 "\"${2}\"" ${1} | cut -d ":" -f 2`

  if [ ! "$LINE" ]; then
    echo "NOT-FOUND" ;
    #echo "Error: Cannot find \"${2}\" in ${1}" >&2;
    #exit 1;
  else
    VALUE=${LINE//,}
    echo $VALUE | sed 's/^[ \t]*//;s/[ \t]*$//'
  fi;
}

function getBlockchainHeightFromNode {
  ./ips-cli getinfo >> node.info
  block=`readJsonValue node.info blocks`
  if [ "$block" = "NOT-FOUND" ]; then
    block=0
  fi
  rm node.info
  echo $block ;
}

function checkBlockchainHeightAndWaitForSync {

    echo
    echo "CHECKING BLOCKCHAIN SYNC..."

    BLOCKCHAIN_HEIGHT=$(curl --silent https://explorer.ipsum.network/api/getblockcount)
    NODE_HEIGHT=`getBlockchainHeightFromNode`

    while [ $NODE_HEIGHT -lt $BLOCKCHAIN_HEIGHT ]
    do
      echo "$NODE_HEIGHT/$BLOCKCHAIN_HEIGHT"
      sleep 5
      BLOCKCHAIN_HEIGHT=$(curl --silent https://explorer.ipsum.network/api/getblockcount)
      NODE_HEIGHT=`getBlockchainHeightFromNode`
    done

    echo "NODE IS FULLY SYNCED... ($NODE_HEIGHT/$BLOCKCHAIN_HEIGHT)"
}

function waitForMasternodePayment {
  echo
  echo "WAITING FOR INCOMING TRANSACTION..."

  TX_ID=""

  while [ "$TX_ID" = "" ]
  do
    ./ips-cli listtransactions 0 1 0 > transaction.last
    amount=`readJsonValue transaction.last amount`
    if [ "$amount" = "5000.00000000" ]
    then
      txid=`readJsonValue transaction.last txid`
      echo ${txid//\"}
      rm transaction.last
      break
    fi
    sleep 10
  done
}

function createMasternodeConfig {
  echo
  echo "CREATING MASTERNODE CONFIGURATION"

  MASTERNODE_ALIAS="$1"

  TX_HASH="NOT-FOUND"
  OUTPUT_IDX="NOT-FOUND"

  while [ "$TX_HASH" = "NOT-FOUND" ]
  do
    sleep 5
    ./ips-cli masternode outputs > masternode_outputs
    TX_HASH=`readJsonValue masternode_outputs txhash`
    TX_HASH=$( echo $TX_HASH | sed 's/^"//;s/"$//')
    OUTPUT_IDX=`readJsonValue masternode_outputs outputidx`
  done

  MASTERNODE_PRIVATE_KEY=$(<masternode_key)

  # alias IP:port masternodeprivkey collateral_output_txid collateral_output_index
  echo "$MASTERNODE_ALIAS $LOCAL_IP:22331 $MASTERNODE_PRIVATE_KEY $TX_HASH $OUTPUT_IDX" >> ~/.ips/masternode.conf

  rm masternode_outputs
}

function checkRunningMasternode {
    PID=$(cat ~/.ips/ipsd.pid)
    if ps -p $PID > /dev/null
    then
       ./ips-cli masternode status > masternode_status
      MESSAGE=`readJsonValue masternode_status message`
      if ! [[ $MESSAGE = *"successfully"* ]]; then
        echo $(date -u) " Masternode not running! Trying to restart." >> checkIPSD.log
        ## TODO: get alias, restart masternode
      fi
    else
       echo $(date -u) " IPSD ($PID) not running!" >> checkIPSD.log
       ./ipsd
    fi
}

function install {

  echo "--------------------------------------------------------------------------------"
  echo "--                                                                            --"
  echo -e "--         YOU ARE ABOUT TO INSTALL A NEW FRESH ${CYAN}IPSUM MASTERNODE${NC}              --"
  echo "--           THIS SCRIPT WILL DELETE OLD DATA RELATED TO IPSUM                --"
  echo "--                                                                            --"
  echo -e "--       ${RED}!!!  ALL DATA OF PREVIOUS INSTALLATIONS WILL BE LOST !!!${NC}             --"
  echo "--                                                                            --"
  echo "--------------------------------------------------------------------------------"
  echo

  read -p "DO YOU WANT TO INSTALL A NEW IPSUM MASTERNODE? [yes/no]: " INSTALL

  if [ "$INSTALL" != "yes" ]; then
    exit;
  fi

  CONF_DIR=~/.ips/
  if [ -d CONF_DIR ]; then
    echo -e "${YELLOW}!!! --- EXISTING CONFIGURATION FOUND --- !!!${NC}"
    read -p "THIS SCRIPT IS INTENDED TO WORK ON A CLEAN FRESH ENVIRONMENT, DO YOU WANT TO CONTINUE ANYWAYS? [yes/no]: " CONTINUE
    if [ "$CONTINUE" != "yes" ]; then
      exit;
    fi
    echo
    echo -e "${YELLOW}CREATING BACKUPS OF CURRENT CONFIGURATION AND TRY TO USE OLD WALLET.${NC}"
    mv ${CONF_DIR}/ips.conf $CONF_DIR/ips.conf_backup
    mv ${CONF_DIR}/masternode.conf $CONF_DIR/masternode.conf_backup
  else
    mkdir -p $CONF_DIR
  fi

  echo
  read -p "TYPE THE ALIAS FOR YOUR MASTERNODE: " MASTERNODE_ALIAS

  if [ -z "$MASTERNODE_ALIAS" ]
  then
    echo "No ALIAS supplied, alias will be: IPS-MN"
    MASTERNODE_ALIAS="IPS-MN"
  fi

  echo
  echo -p "DO YOU HAVE A MASTERNODE KEY AND A WALLET ADDRESS ALREADY? [yes/no]: " KEY_EXIST
  if [ "$KEY_EXIST" = "yes" ]; then
    echo
    read -p "TYPE IN YOUR MASTERNODE KEY: " masternode_key
    read -p "TYPE IN YOU MASTERNODE WALLET ADDRESS: " masternode_wallet
  fi

  echo

  ## update environment
  sudo apt-get -y update
  sudo apt-get -y upgrade
  sudo apt autoremove -y && sudo apt-get update
  sudo apt-get install -y libzmq3-dev libminiupnpc-dev libssl-dev libevent-dev
  sudo apt-get install -y build-essential libtool autotools-dev automake pkg-config
  sudo apt-get install -y bsdmainutils software-properties-common
  sudo apt-get install -y libboost-all-dev
  sudo add-apt-repository ppa:bitcoin/bitcoin -y
  sudo apt-get update
  sudo apt-get install -y libdb4.8-dev libdb4.8++-dev

  # load current IPS release
  wget https://github.com/ipsum-network/ips/releases/download/v3.1.0.0/ips-3.1.0-linux.tar.gz
  tar xvzf ips-3.1.0-linux.tar.gz
  rm ips-cli
  cp ./ips-3.1.0/bin/ips-cli .
  rm ipsd
  cp ./ips-3.1.0/bin/ipsd .

  CONF_FILE=ips.conf
  CONF_TEMP=temp.conf

  echo "rpcuser=user"`shuf -i 100000-10000000 -n 1` >> CONF_TEMP
  echo "rpcpassword=pass"`shuf -i 100000-10000000 -n 1` >> CONF_TEMP
  echo "rpcallowip=127.0.0.1" >> CONF_TEMP
  echo "rpcport=22332" >> CONF_TEMP
  echo "listen=1" >> CONF_TEMP
  echo "server=1" >> CONF_TEMP
  echo "daemon=1" >> CONF_TEMP
  echo "staking=0" >> CONF_TEMP
  echo "txindex=1" >> CONF_TEMP
  echo "logtimestamps=1" >> CONF_TEMP
  echo "port=22331" >> CONF_TEMP
  echo "externalip=$LOCAL_IP:22331" >> CONF_TEMP

  wget -q https://github.com/ipsum-network/seeds/raw/master/README.md
  LINES=$(< README.md wc -l)
  END=$((LINES - 1))
  sed -n "7,$END p" < README.md > SEED_NODES

  cat CONF_TEMP SEED_NODES > $CONF_DIR/$CONF_FILE

  ./ipsd

  checkBlockchainHeightAndWaitForSync

  if [ "$KEY_EXIST" != "yes" ]; then
    masternode_key=$(./ips-cli masternode genkey)
    masternode_wallet=$(./ips-cli getaccountaddress 0)
  fi

  echo $masternode_key > masternode_key
  echo $masternode_wallet > masternode_wallet

  echo -e "NOW SEND ${RED}EXACTLY ${YELLOW}5000${NC} IPS TO THIS ADDRESS: ${CYAN}$masternode_wallet${NC}"

  waitForMasternodePayment

  createMasternodeConfig $MASTERNODE_ALIAS

  ./ips-cli stop

  echo "masternode=1" >> CONF_TEMP
  echo "masternodeprivkey=$masternode_key" >> CONF_TEMP
  echo "" >> CONF_TEMP

  cat CONF_TEMP SEED_NODES > $CONF_DIR/$CONF_FILE

  # start masternode
  ./ipsd

  sleep 5

  ./ips-cli startmasternode alias 0 $MASTERNODE_ALIAS

  sleep 1

  ./ips-cli masternode start $MASTERNODE_ALIAS

  sleep 1

  ./ips-cli masternode status > masternode_status
  MESSAGE=`readJsonValue masternode_status message`
  if ! [[ $MESSAGE = *"successfully"* ]]; then
    echo
    echo -e "${RED}!!! - COULD NOT START MASTERNODE - !!!${NC}"
    exit
  fi

  # enable staking
  ./ips-cli stop
  sed -i '/staking=0/c\staking=1' $CONF_DIR/$CONF_FILE

  ./ipsd

  # remove all temp files
  rm masternode_status
  rm README.md
  rm SEED_NODES
  rm CONF_TEMP

  # AND DONE!
  echo -e "${GREEN}Congratulations!!! Your masternode $MASTERNODE_ALIAS is up and running!${NC}"
}

case "$1" in
    install)
       install
       ;;
    update)
       echo "UPDATE NOT YET IMPLEMENTED!"
       ;;
    status)
       checkBlockchainHeightAndWaitForSync
       ;;
    check)
        checkRunningMasternode
       ;;
    *)
       echo "Usage: $0 {install|update|status}"
esac
