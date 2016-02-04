#!/bin/bash

# print commands and arguments as they are executed
set -x

echo "initializing geth installation"
date
ps axjf

#############
# Parameters
#############

AZUREUSER=$1
HOMEDIR="/home/$AZUREUSER"
VMNAME=`hostname`
echo "User: $AZUREUSER"
echo "User home dir: $HOMEDIR"
echo "vmname: $VMNAME"

# Fetch Genesis and scripts
cd $HOMEDIR
wget https://raw.githubusercontent.com/Azure/azure-devtestlab/master/Artifacts/linux-go-ethereum/lab-seed.json
wget https://raw.githubusercontent.com/Azure/azure-devtestlab/master/Artifacts/linux-go-ethereum/seed-blockchain.sh
wget https://raw.githubusercontent.com/Azure/azure-devtestlab/master/Artifacts/linux-go-ethereum/start-blockchain.sh
wget https://raw.githubusercontent.com/Azure/azure-devtestlab/master/Artifacts/linux-go-ethereum/ssh443.sh
wget https://raw.githubusercontent.com/Azure/azure-devtestlab/master/Artifacts/linux-go-ethereum/attachOne.sh

#####################
# setup the Azure CLI
#####################
time sudo npm install azure-cli -g
time sudo update-alternatives --install /usr/bin/node nodejs /usr/bin/nodejs 100

####################
# Setup Geth
####################
time sudo apt-get -y git
time sudo apt-get install -y software-properties-common
time sudo add-apt-repository -y ppa:ethereum/ethereum
time sudo add-apt-repository -y ppa:ethereum/ethereum-dev
time sudo apt-get update
time sudo apt-get install -y ethereum

####################
# Install sol compiler
####################
time sudo add-apt-repository ppa:ethereum/ethereum -y
time sudo apt-get update
time sudo apt-get install solc -y

####################
# Listen on 443 for SSH
####################
#time sudo sh ssh443.sh
#time sudo service ssh restart

date
echo "completed geth install $$"
