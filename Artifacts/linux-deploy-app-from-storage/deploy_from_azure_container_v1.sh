#!/bin/bash

###
# Arguments:
#
# $1    Container name
# $2    Destination
# $3    Connection string
# $4    Deployment script
#
###

isApt=`command -v apt-get`
isYum=`command -v yum`

if [ -n "$isApt" ] ; then
    echo "Using APT package manager"

    apt-get -y update
    
    curl -sL https://deb.nodesource.com/setup_4.x | sudo -E bash -
    apt-get -y install nodejs
    apt-get -y install npm
    
    nde="nodejs"
    
elif [ -n "$isYum" ] ; then
    echo "Using YUM package manager"

    yum -y update
    yum clean all
    
    yum install -y epel-release
    yum install -y nodejs npm
    
    nde="node"
fi

npm install azure-storage
npm install mkdirp

set -e

# clean deployment folder prior to download
rm -d -f -r $2

# download the container into the destination folder
eval "$nde ./download_azure_container.js '$1' '$2' '$3'"

# run the install script if one is provided
if [ -n "$4" ]; then
	echo "invoking $2/$4"
	sh "$2/$4"
fi