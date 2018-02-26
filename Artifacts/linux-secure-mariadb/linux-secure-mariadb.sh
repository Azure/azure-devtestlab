#!/bin/bash
#
# Script to secure MariaDB installation on Linux.
# Based on mysql_secure_installation.sh found here https://github.com/twitter/mysql/blob/master/scripts/mysql_secure_installation.sh
#
# NOTE: Intended for use by the Azure DevTest Lab artifact system.
#
# Usage: 
#
# linux-secure-mariadb.sh -p (root password)
#

# Default argument values
USAGE_STRING="Usage:
linux-secure-mariadb.sh -p (root password)
root password
    Specify new root password
"

# Initialize logger
export LOGCMD='logger -i -t azure-devtestlab --'
which logger
if [ $? -ne 0 ] ; then
    LOGCMD='echo [azure-devtestlab] '
fi

# Check for minimum number of parameters first - must be at minimum 1
if [ $# -lt 1 ] ; then
    $LOGCMD "ERROR: This script needs at least 1 command-line argument, password=."
    $LOGCMD "$USAGE_STRING"
    exit 1
fi

# Get parameter value for password
while getopts p: option
do
    case "${option}"
    in
    p) ROOT_PASSWORD=${OPTARG};;
    esac
done

set -e

# Set root password and make sure that nobody can access the server without a password
$LOGCMD "Updating root password"
mysql -e "UPDATE mysql.user SET Password=PASSWORD('$ROOT_PASSWORD') WHERE User='root';"

# Remove anonymous users
$LOGCMD "Removing anonymous users"
mysql -e "DELETE FROM mysql.user WHERE User='';"

# Disallow root login remotely
$LOGCMD "Disallowing root login remotely"
mysql -e "DELETE FROM mysql.user WHERE User='root' AND Host NOT IN ('localhost', '127.0.0.1', '::1');"

# Remove test database and access to it. Use IF EXISTS since sometimes
# test database is not present (e.g. Debian based systems) 
$LOGCMD "Removing test database and access to it"
mysql -e "DROP DATABASE IF EXISTS test;"
mysql -e "DELETE FROM mysql.db WHERE Db='test' OR Db='test\\_%';"

# Reload privilege tables
$LOGCMD "Reloading privilege tables"
mysql -e "FLUSH PRIVILEGES;"

$LOGCMD "Finished securing MariaDB installation"

set +e
