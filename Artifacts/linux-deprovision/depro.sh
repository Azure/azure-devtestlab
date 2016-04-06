

#!/bin/bash
nohup sh -c 'sleep 15 && /usr/sbin/waagent -force -deprovision+user' > /dev/null  &

exit 0


