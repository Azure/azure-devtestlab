#!/bin/bash

###
# Arguments:
#
# $1    Swap file size
#
###

set -e

# Generate a file name based on the current date to avoid naming conflicts.
SIZE="$1"
FILENAME="$(date +%s | sha256sum | base64 | head -c 32)"
FILEPATH="/mnt/$FILENAME"

# In previous versions of this script, we used fallocate. But that started failing on newer
# OS versions. So, although fallocate can be faster, we are changing to use dd instead. The
# nomenclature is slightly different. So, we need to make sure the user is aware of it.
# For example, to create a 1 GB swap file, the caller will need to specify 1073741824 (bytes)
# or 1G. Note that case here is important.
dd if=/dev/zero of=$FILEPATH bs=$SIZE count=1

chmod 600 $FILEPATH
mkswap $FILEPATH
swapon $FILEPATH

echo “$FILEPATH  none  swap  sw  0 0” >> /etc/fstab
