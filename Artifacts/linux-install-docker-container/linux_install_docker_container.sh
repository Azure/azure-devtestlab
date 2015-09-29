#!/bin/bash

###
# Arguments:
#
# $1    Container name
# $2    Docker run options
# $3    Image name
# 4$    Additional image arguments
#
###

sudo apt-get -y update
sudo apt-get -y install docker.io

if [ -z "$1" ] ; then
    NAME_ARG=
else
    NAME_ARG=" --name $1"
fi

# Docker run syntax: docker run [OPTIONS] IMAGE:TAG [COMMAND] [ARG...]
#                               |__1-2__| |___3___| |_______ 4_______|

cmd="sudo docker run $NAME_ARG $2 -d $3 $4"

echo "Running command: $cmd"
eval $cmd