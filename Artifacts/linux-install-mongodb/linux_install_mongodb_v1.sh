#!/bin/bash

set -e

if [ -f /usr/bin/apt ] ; then
    echo "Using APT package manager"
    
    apt-get -y update
    apt-get -y install mongodb
elif [ -f /usr/bin/yum ] ; then 
    echo "Using YUM package manager"

    yum clean all
    yum -y update
    
    releasever=7
    cat >/etc/yum.repos.d/mongodb-org-3.0.repo <<-EOF
[mongodb-org-3.0]
name=MongoDB Repository
baseurl=https://repo.mongodb.org/yum/redhat/$releasever/mongodb-org/3.0/x86_64/
gpgcheck=0
enabled=1
EOF
    
    yum install -y mongodb-org
    
    service mongod start
    chkconfig mongod on
fi