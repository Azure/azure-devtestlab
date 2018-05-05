#!/bin/bash

echo "Installing MongoDb"

isApt=`command -v apt-get`
isYum=`command -v yum`

# Some of the previous commands will fail with an exit code other than zero (intentionally), 
# so we do not set error handling to stop (set e) until after they've run
set -e

if [ -n "$isApt" ] ; then
    echo "Using APT package manager"
    
    apt-get -y update
    apt-get -y install mongodb
elif [ -n "$isYum" ] ; then
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
