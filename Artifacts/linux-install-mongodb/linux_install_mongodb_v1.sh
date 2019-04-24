#!/bin/bash

echo "Starting MongoDb installation."

isApt=`command -v apt-get`
isYum=`command -v yum`

# Some of the previous commands will fail with an exit code other than zero (intentionally), 
# so we do not set error handling to stop (set e) until after they've run.
set -e

if [ -n "$isApt" ] ; then
    echo "Using APT package manager."
    
    echo "Updating every installed package."
    apt-get -y update

    echo "Installing MongoDb."
    apt-get -y install mongodb
elif [ -n "$isYum" ] ; then
    echo "Using YUM package manager."

    echo "Cleaning everything."
    rm -r /var/cache/yum -f
    yum clean all
    echo "Updating every installed package."
    yum -y update --disablerepo=rhui-microsoft-azure-rhel7,microsoft-azure-rhel7

    echo "Preparing MongoDb installation configuration."
    releasever=7
    cat >/etc/yum.repos.d/mongodb-org-3.0.repo <<-EOF
[mongodb-org-3.0]
name=MongoDB Repository
baseurl=https://repo.mongodb.org/yum/redhat/$releasever/mongodb-org/3.0/x86_64/
gpgcheck=0
enabled=1
EOF

    echo "Installing MongoDb."
    yum install -y mongodb-org --disablerepo=rhui-microsoft-azure-rhel7,microsoft-azure-rhel7
fi

echo "Artifact completed successfully."