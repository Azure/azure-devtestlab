#!/bin/bash

set -e
sudo waagent -force -deprovision+user
sudo shutdown -P 5
