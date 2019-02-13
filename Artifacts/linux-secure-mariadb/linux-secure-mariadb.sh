#!/bin/bash
#
# Script to secure MariaDB installation on Linux.
# Based on mysql_secure_installation.sh found here https://github.com/twitter/mysql/blob/master/scripts/mysql_secure_installation.sh
#
# NOTE: Intended for use by the Azure DevTest Lab artifact system.
#
# Usage: 
#
# linux-secure-mariadb.sh [-p password]
#

# Get parameter value for password
usage() { echo "Usage: $0 [-p password]" 1>&2; exit 1; }

while getopts ":p:" option; do
    case "${option}" in
        p)
            p=${OPTARG}
            ;;
        *)
            usage
            ;;
    esac
done
shift $((OPTIND-1))

if [ -z "${p}" ]; then
    usage
fi


set -e

# Check if mariadb is running
running=$(pgrep mysql | wc -l)
if [ "$running" -eq 0 ];
then
        echo "MariaDB not running. Aborting"
        exit 1
else
        echo "Found running MariaDB instance"
fi

# Check if mysql is available
echo "Checking if mysql command is available"
command -v mysql >/dev/null 2>&1 || { echo >&2 "mysql command is required but not installed. Aborting"; exit 1; }

# Set root password and make sure that nobody can access the server without a password
echo "Updating root password"
mysql -e "UPDATE mysql.user SET Password=PASSWORD('$ROOT_PASSWORD') WHERE User='root';"

# Remove anonymous users
echo "Removing anonymous users"
mysql -e "DELETE FROM mysql.user WHERE User='';"

# Disallow root login remotely
echo "Disallowing root login remotely"
mysql -e "DELETE FROM mysql.user WHERE User='root' AND Host NOT IN ('localhost', '127.0.0.1', '::1');"

# Remove test database and access to it. Use IF EXISTS since sometimes
# test database is not present (e.g. Debian based systems) 
echo "Removing test database and access to it"
mysql -e "DROP DATABASE IF EXISTS test;"
mysql -e "DELETE FROM mysql.db WHERE Db='test' OR Db='test\\_%';"

# Reload privilege tables
echo "Reloading privilege tables"
mysql -e "FLUSH PRIVILEGES;"

echo "Done securing MariaDB installation"

set +e
