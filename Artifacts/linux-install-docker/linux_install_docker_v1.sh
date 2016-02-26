#!/bin/bash

set -e

if [ -f /usr/bin/apt ] ; then
    echo "Using APT package manager"
    apt-get -y update
    apt-get -y install docker.io
elif [ -f /usr/bin/yum ] ; then 
    echo "Using YUM package manager"

    yum -y update
    
    tee /etc/yum.repos.d/docker.repo <<-'EOF'
    [dockerrepo]
    name=Docker Repository
    baseurl=https://yum.dockerproject.org/repo/main/centos/$releasever/
    enabled=1
    gpgcheck=1
    gpgkey=https://yum.dockerproject.org/gpg
    EOF    

    yum install -y docker-engine

    service docker start
fi