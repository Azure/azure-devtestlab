#!/bin/bash

set -e

if [ -f /usr/bin/apt ] ; then
    echo "Using APT package manager"
    apt-get -y update
    apt-get -y install docker.io
elif [ -f /usr/bin/yum ] ; then 
    echo "Using YUM package manager"

    yum -y update
    yum install -y docker

    systemctl start docker
    systemctl enable docker
fi