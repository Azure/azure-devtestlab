#!/bin/bash
set -e
(sleep 5; waagent -force -deprovision+user) &
exit 0
