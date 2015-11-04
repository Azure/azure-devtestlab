#!/bin/bash

###
# Arguments:
#
# $1    Swap file size
#
###

set -e

# Generate a file name based on the current date to avoid naming conflicts
SIZE="$1"
FILENAME="$(date +%s | sha256sum | base64 | head -c 32)"
FILEPATH="/mnt/$FILENAME"

fallocate -l $SIZE $FILEPATH
chmod 600 $FILEPATH
mkswap $FILEPATH
swapon $FILEPATH
echo “$FILEPATH  none  swap  sw  0 0” >> /etc/fstab
