#!/bin/bash

trace() { 
    echo ">>> $@" && echo ">>> $@" 1>&2
}

isApt=`command -v apt-get`
isYum=`command -v yum`

if [ -n "$isApt" ] ; then
    trace "Using APT package manager"
    
    sudo apt-get update && sudo apt-get upgrade -y  
    sudo apt-get -y install xrdp xfce4

    if [ ! -f ~/.xsession ] ; then

        trace "Register XFCE4 as session manager"
        echo “xfce4-session” > ~/.xsession
    fi

    /etc/init.d/xrdp start

elif [ -n "$isYum" ] ; then
    trace "Using YUM package manager"

    yum install epel-release -y

fi