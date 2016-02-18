#!/bin/bash

set -e
sudo waagent -force -deprovision+user

sudo shutdown -h +5 "Deprovisioning complete shutting down in 5 minutes"
