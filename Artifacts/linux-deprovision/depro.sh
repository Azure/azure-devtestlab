#!/bin/bash

set -e
echo -e "\n"|sudo -S waagent -force -deprovision+user
