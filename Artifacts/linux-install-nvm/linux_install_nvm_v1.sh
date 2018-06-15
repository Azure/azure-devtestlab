# Script to install NVM on Linux package on Azure DevTest lab Linux VMs.
#
# NOTE: Intended for use by the Azure DevTest Lab artifact system.
#
# Usage: 
#
# linux_install_nvm_v1.sh TARGET-USER
#

#!/bin/bash

#Get the input parameter value.
TARGET_USER=$1

# Check if nvm is already installed.
echo "Checking if NVM is already installed."
echo "For user $TARGET_USER"
runuser -l $TARGET_USER -c 'nvm -v'
installationStatus=$(echo $?)

if [ $installationStatus -eq 127 ] ; then
    echo "Installing NVM..."
    runuser -l $TARGET_USER -c 'wget -qO- https://raw.githubusercontent.com/creationix/nvm/v0.33.8/install.sh | bash'
    echo "Installed NVM for user $TARGET_USER."
else
    echo "NVM is already installed."
fi

echo "Done."