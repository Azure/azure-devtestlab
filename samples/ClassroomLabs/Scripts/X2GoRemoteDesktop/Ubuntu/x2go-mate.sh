#!/bin/sh

set -e

error() {
    echo ${RED}"Error: $@"${RESET} >&2
}

setup_color() {
    # Only use colors if connected to a terminal
    if [ -t 1 ]; then
        RED=$(printf '\033[31m')
        GREEN=$(printf '\033[32m')
        YELLOW=$(printf '\033[33m')
        BLUE=$(printf '\033[34m')
        BOLD=$(printf '\033[1m')
        RESET=$(printf '\033[m')
    else
        RED=""
        GREEN=""
        YELLOW=""
        BLUE=""
        BOLD=""
        RESET=""
    fi
}


main() {

    setup_color

    
    echo "${BLUE}Adding x2go PPA repo...${RESET}"

    apt-get install -y software-properties-common

    add-apt-repository -y ppa:x2go/stable


    echo "${BLUE}Updating apt package repository...${RESET}"

    apt-get update

    sleep 2

    
    echo "${BLUE}Intalling MATE desktop and x2go server...${RESET}"

    apt-get install -y ubuntu-mate-desktop x2goserver x2goserver-xsession x2gomatebindings


    echo "${GREEN}MATE desktop and x2go successfully installed!${RESET}"    
}

main