#!/bin/bash
set -e
nohup sh -c 'sleep 15 && /usr/sbin/waagent -force -deprovision+user' > /dev/null  &
disown
exit 0
#shutdown -h +5
