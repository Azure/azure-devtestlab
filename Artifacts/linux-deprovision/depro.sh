#!/bin/bash

set -e
sudo waagent -force -deprovision+user

sudo shutdown -p+5
