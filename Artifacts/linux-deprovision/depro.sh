#!/bin/sh

main () {
    { # try
        echo 'waagent -force -deprovision+user && poweroff' | at now + 1 minute > /dev/null 2>&1
        exit 0
    } || { # catch
        exit 1
    }
}

main "$@"
