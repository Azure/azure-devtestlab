

#!/bin/bash
OS=$(lsb_release -si)
ARCH=$(uname -m | sed 's/x86_//;s/i[3-6]86/32/')
VER=$(lsb_release -sr)
if [ $VER = 15.10 ]
        then 
             nohup sh -c 'sleep 15 && /usr/sbin/waagent2.0 -force -deprovision+user' > /dev/null &
        else 
            nohup sh -c 'sleep 15 && /usr/sbin/waagent -force -deprovision+user' > /dev/null  &
fi
#set -e
#nohup sh -c 'sleep 15 && /usr/sbin/waagent -force -deprovision+user' > /dev/null  &
exit 0
#shutdown -h +5

