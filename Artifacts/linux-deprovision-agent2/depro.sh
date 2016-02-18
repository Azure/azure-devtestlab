#!/bin/bash

set -e
sudo waagent2.0 -force -deprovision+user

sudo shutdown -h +5 &
