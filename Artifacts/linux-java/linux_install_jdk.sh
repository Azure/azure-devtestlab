#!/bin/bash

# script to install Java on Ubuntu (APT) systems or YUM-based systems.
# 
# Update the package system prior to installing Java to ensure we can get what we need.
#
# Version 0.1
# Author Darren Rich <darrich@microsoft.com>
# Original version found on VSTS: https://almrangers.visualstudio.com/

set -e

if [ -f /usr/bin/apt ] ; then
    echo "Using APT package manager"

    sudo apt-get -y update
    
    sudo apt-get -y install default-jdk
    
elif [ -f /usr/bin/yum ] ; then 
    echo "Using YUM package manager"

    yum -y update
    yum clean all
    
    yum install -y java-1.8.0-openjdk
fi
