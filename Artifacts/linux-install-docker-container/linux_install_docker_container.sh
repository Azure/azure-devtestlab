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

if [ -f /usr/bin/apt ] ; then
    echo "Using APT package manager"

    apt-get -y update
    apt-get -y install docker.io
elif [ -f /usr/bin/yum ] ; then 
    echo "Using YUM package manager"

    yum -y update
    yum install -y docker

    systemctl start docker
    systemctl enable docker
fi

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