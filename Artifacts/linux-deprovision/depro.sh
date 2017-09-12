#!/bin/sh

main () {
    { # try
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
