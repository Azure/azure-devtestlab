#!/bin/sh

main () {
    { # try

        # The script runs as root, try to install at command and return 1 if system not supported
        isApt=`command -v apt-get`
        isYum=`command -v yum`
        isZypper=`command -v zypper`
        if [ -n "$isApt" ] ; then
            apt-get -y update > /dev/null
            apt-get -y install at > /dev/null
        elif [ -n "$isYum" ] ; then
            yum install -y at > /dev/null
        elif [ -n "$isZypper" ] ; then
            zypper install -y at > /dev/null
        else
            echo 'OS type not supported' #> /dev/null 2>&1
            exit 1
        fi

        # Make sure that the atd service is running to cover our dependency below.
        isSystemctl=`command -v systemctl`
        if [ -n "$isSystemctl" ] ; then
            systemctl enable atd.service && systemctl start atd.service > /dev/null
        else
            insserv atd && /etc/init.d/atd start > /dev/null
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
