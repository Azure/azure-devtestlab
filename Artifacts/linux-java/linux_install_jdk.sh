#!/bin/bash

# script to install Java on Ubuntu (APT) systems or YUM-based systems.
# 
# Update the package system prior to installing Java to ensure we can get what we need.
#
# Version 0.1
# Author Darren Rich <darrich@microsoft.com>
# Original version found on VSTS: https://almrangers.visualstudio.com/

echo "Installing Java"

isApt=`command -v apt-get`
isYum=`command -v yum`

# Some of the previous commands will fail with an exit code other than zero (intentionally), 
# so we do not set error handling to stop (set e) until after they've run
set -e

if [ -n "$isApt" ] ; then
    echo "Using APT package manager"

    sudo apt-get -y update
    
    sudo apt-get -y install default-jdk
    exit 0
elif [ -n "$isYum" ] ; then
    echo "Using YUM package manager"

    yum -y update
    yum clean all
    
    yum install -y java-1.8.0-openjdk
    exit 0
fi

exit 1
