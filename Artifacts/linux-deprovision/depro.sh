#!/bin/sh

main () {
    { # try

        # The script runs as root, try to install at command and return 1 if system not supported
        if [ -f /usr/bin/apt ] ; then
            apt-get --assume-yes update > /dev/null
            apt-get --assume-yes install at > /dev/null
        elif [ -f /usr/bin/yum ] ; then 
            yum -y update
            yum install -y at
        else
            echo "OS type not supported"
            exit 1
        fi

        # chdir to waagent's directory before running it
        waagentPath=$(command -v waagent)
        # trim the last 8 characters
        waagentDir=${waagentPath%????????}       
        echo "cd $waagentDir && waagent -force -deprovision+user > /tmp/depro.out 2> /tmp/depro.err && poweroff" | at now + 1 minute > /dev/null 2>&1        
        exit 0
    } || { # catch
        exit 1
    }
}

main "$@"
