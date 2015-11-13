#!/bin/bash

set -e

if [ -f /usr/bin/apt ] ; then
    echo "Using APT package manager"

    apt-get -y update
    
    curl --silent --location https://deb.nodesource.com/setup_0.12 | bash -
    apt-get -y install nodejs
    
elif [ -f /usr/bin/yum ] ; then 
    echo "Using YUM package manager"

    yum -y update
    yum clean all
    
    yum install -y epel-release
    yum install -y nodejs npm
fi