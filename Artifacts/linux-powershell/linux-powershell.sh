# Script to install PowerShell on Linux package on Azure DevTest lab Linux VMs.
#
# NOTE: Intended for use by the Azure DevTest Lab artifact system.
#
# Usage: 
#
# linux-powershell.sh PACKAGE-URL
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
    if [ $(lsb_release -r -s) = "16.04" ]; then
        apt-get -q -y install libunwind8 libicu55
        dpkg -i $FILE_NAME
    elif [ $(lsb_release -r -s) = "14.04" ]; then
        apt-get -q -y install libunwind8 libicu52
        dpkg -i $FILE_NAME
    fi
fi
