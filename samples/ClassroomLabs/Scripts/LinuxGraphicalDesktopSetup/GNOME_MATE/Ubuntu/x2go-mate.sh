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

    echo "${BLUE}Installing MATE desktop and x2go server...${RESET}"

    apt-get install -y ubuntu-mate-desktop x2goserver x2goserver-xsession x2gomatebindings

    echo "${GREEN}MATE desktop and x2go successfully installed!${RESET}"

    # The following steps are needed to work around a conflict between MATE desktop and the Azure Linux VM agent.  Specifically, the conflict occurs when MATE installs 
    # ifupdown.  Ifupdown conflicts with netplan/cloud-init which causes the VM to fail to get its IP address during first boot.  As a result, the Azure Linux VM
    # agent remains in a "Not Ready" state when a new VM is provisioned with an image with MATE desktop installed.  
    # Here is more info about how these tools interact with one another:
    #   - ifupdown is used by the network management daemon, systemd networkd
    #   - netplan uses the systemd networkd daemon to provide network information to cloud-init
    #   - cloud-init runs during a VM's initial boot process to set up the VM
    # The workaround is to remove netplan and disable the systemd networkd daemon so that instead the Network Manager daemon and ifupdown are used for networking (Note: MATE
    # prefers using Network Manager).  See the following bug: https://bugs.launchpad.net/ubuntu/+source/cloud-init/+bug/1832381.

    currentversion=$(grep '^VERSION_ID' /etc/os-release)
    targetversion="18.04"

    case "$currentversion" in
        *"$targetversion"*)  
            echo "${BLUE}Configuring networking workaround for MATE and Azure Linux VM agent...${RESET}"

            apt-get remove -y netplan.io

            systemctl disable systemd-networkd

            cat > /etc/network/interfaces <<EOF
                auto lo
                iface lo inet loopback
                source /etc/network/interfaces.d/*.cfg
EOF

            echo "${GREEN}Networking workaround is completed!${RESET}"  ;;
         *)     echo "Skipping networking work around"
    esac          
}
main