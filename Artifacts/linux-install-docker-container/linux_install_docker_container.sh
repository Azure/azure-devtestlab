#!/bin/bash

set -e

###
# Arguments:
#
# $1    Container name
# $2    Docker run options
# $3    Image name
# 4$    Additional image arguments
#
###

wget -qO- https://get.docker.com/ | sh

if [ -z "$1" ] ; then
    NAME_ARG=
else
    NAME_ARG=" --name $1"
fi

# Docker run syntax: docker run [OPTIONS] IMAGE:TAG [COMMAND] [ARG...]
#                               |__1-2__| |___3___| |_______ 4_______|

cmd="docker run $NAME_ARG $2 -d $3 $4"

echo "Running command: $cmd"
eval $cmd