#!/bin/bash

###
# Arguments:
#
# $1    Container name
# $2    Docker run options
# $3    Image name
# $4    Additional image arguments
#
###

# Check if docker is already installed.
docker -v
installationStatus=$(echo $?)

if [ $installationStatus -eq 127 ] ; then
    wget -qO- https://get.docker.com/ | sh
fi

if [ -z "$1" ] ; then
    NAME_ARG=
else
    NAME_ARG=" --name $1"
fi

# Docker run syntax: docker run [OPTIONS] IMAGE [COMMAND] [ARG...]
#                               |__1-2__| |_3_| |_______ 4_______|

cmd="docker run $NAME_ARG $2 -d $3 $4"

echo "Running command: $cmd"
eval $cmd
