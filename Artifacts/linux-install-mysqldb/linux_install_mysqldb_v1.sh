#!/bin/bash

echo "Installing MySql"

isZypper=`command -v zypper`

# Some of the previous commands will fail with an exit code other than zero (intentionally),

# so we do not set error handling to stop (set e) until after they've run

set -e

if [ -n "$isZypper" ] ; then

    echo "Using zypper package manager"

    zypper install -y mysql-server

    service mysql start

    chkconfig mysql on

fi

# devtestmysql