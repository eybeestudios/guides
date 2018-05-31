#!/bin/bash

function readJsonValue {
  UNAMESTR=`uname`
  if [[ "$UNAMESTR" == 'Linux' ]]; then
    SED_EXTENDED='-r'
  elif [[ "$UNAMESTR" == 'Darwin' ]]; then
    SED_EXTENDED='-E'
  fi;

  LINE=`grep -m 1 "\"${2}\"" ${1} | cut -d ":" -f 2`

  if [ ! "$LINE" ]; then
    echo "NOT-FOUND" ;
    #echo "Error: Cannot find \"${2}\" in ${1}" >&2;
    #exit 1;
  else
    VALUE=${LINE//,}
    echo "${VALUE##*( )}" ;
  fi;
}

function getBlockchainHeightFromNode {
  ./ips-cli getinfo >> node.info
  block=`readJsonValue node.info blocks`
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
    echo "--$amount--"
    if [ "$amount" = "5000.00000000" ]
    then
      echo "amount: $amount"
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
}

function install {

  #!/bin/bash
  RED='\033[0;31m'
  GREEN='\033[0;32m'
  CYAN='\033[0;36m'
  NC='\033[0m' # No Color

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
  read -p "TYPE THE ALIAS FOR YOUR MASTERNODE: " MASTERNODE_ALIAS

  if [ "$INSTALL" != "yes" ]; then
    exit;
  fi

  echo

  CONF_DIR=~/.ips/
  if [ -d CONF_DIR ]; then
    rm ips*
    rm -r ~/.ips
  fi
  mkdir -p $CONF_DIR

  sudo apt-get -y update
  sudo apt-get -y upgrade
  wget https://github.com/ipsum-network/ips/releases/download/v3.1.0.0/ips-3.1.0-linux.tar.gz
  tar xvzf ips-3.1.0-linux.tar.gz
  cp ./ips-3.1.0/bin/ips-cli .
  cp ./ips-3.1.0/bin/ipsd .
  sudo apt autoremove -y && sudo apt-get update
  sudo apt-get install -y libzmq3-dev libminiupnpc-dev libssl-dev libevent-dev
  sudo apt-get install -y build-essential libtool autotools-dev automake pkg-config
  sudo apt-get install -y bsdmainutils software-properties-common
  sudo apt-get install -y libboost-all-dev
  sudo add-apt-repository ppa:bitcoin/bitcoin -y
  sudo apt-get update
  sudo apt-get install -y libdb4.8-dev libdb4.8++-dev
  mkdir -p ~/.ips

  LOCAL_IP=$(ifconfig | grep -Eo 'inet (addr:)?([0-9]*\.){3}[0-9]*' | grep -Eo '([0-9]*\.){3}[0-9]*' | grep -v '127.0.0.1')

  CONF_FILE=ips.conf
  CONF_TEMP=temp.conf

  echo "rpcuser=user"`shuf -i 100000-10000000 -n 1` >> CONF_TEMP
  echo "rpcpassword=pass"`shuf -i 100000-10000000 -n 1` >> CONF_TEMP
  echo "rpcallowip=127.0.0.1" >> CONF_TEMP
  echo "rpcport=22332" >> CONF_TEMP
  echo "listen=1" >> CONF_TEMP
  echo "server=1" >> CONF_TEMP
  echo "daemon=1" >> CONF_TEMP
  echo "staking=1" >> CONF_TEMP
  echo "txindex=1" >> CONF_TEMP
  echo "logtimestamps=1" >> CONF_TEMP
  echo "port=22331" >> CONF_TEMP
  echo "externalip=$LOCAL_IP:22331" >> CONF_TEMP

  wget https://github.com/ipsum-network/seeds/raw/master/README.md
  LINES=$(< README.md wc -l)
  END=$((LINES - 1))
  sed -n "7,$END p" < README.md > SEED_NODES
  rm README.md

  cat CONF_TEMP SEED_NODES > $CONF_DIR/$CONF_FILE

  ./ipsd

  checkBlockchainHeightAndWaitForSync

  masternode_key=$(./ips-cli masternode genkey)
  echo $masternode_key >> masternode_key
  masternode_wallet=$(./ips-cli getaccountaddress 0)
  echo $masternode_wallet >> masternode_wallet

  echo "NOW SEND EXACTLY 5000 IPS TO THIS ADDRESS: $masternode_wallet"

  waitForMasternodePayment
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
    payment)
      waitForMasternodePayment
       ;;
    *)
       echo "Usage: $0 {install|update|status}"
esac
