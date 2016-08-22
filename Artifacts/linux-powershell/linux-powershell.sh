# Script to install PowerShell on Linux package on Azure DevTest lab Linux VMs.
#
# NOTE: Intended for use by the Azure DevTest Lab artifact system.
#
# Usage: 
#
# linux-apt-package.sh PACKAGE-URL
#

#!/bin/bash

set -e
cd /tmp
URL=$1
FILE_NAME="${URL##*/}"
echo "Downloading $FILE_NAME"
wget $URL

if [ -f /usr/bin/yum ] ; then
    echo "Using yum package manager"
    yum install -y $FILE_NAME
elif [ -f /usr/bin/apt ] ; then
    echo "Using apt package manager"
    apt-get -q -y install libunwind8 libicu55
    dpkg -i $FILE_NAME
fi
