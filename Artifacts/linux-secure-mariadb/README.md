# Linux Secure MariaDB Artifact
This Azure DevTest artifact allows the user to secure MariaDB installations already present on a Azure DevTest Lab VM (for example installed via Apt/Yum Package Manager Artifact). This artifact applies to any Linux distribution.

The script is based on [Twitters implementation of mysql_secure_installation.sh](https://github.com/twitter/mysql/blob/master/scripts/mysql_secure_installation.sh) and basically does the following:
*Set root password and make sure that nobody can access the server without a password
*Remove anonymous users
*Disallow root login remotely
*Remove test database and access to it
*Reload privilege tables

## Usage 
The script is intended for use in the Azure DevTest Labs artifact system, and the parameters for the artifact are fed directly
into the script. However, you can run it from any bash shell using the following format:

        bash> ./linux-secure-mariadb.sh [-p=password]  

## Compatibility
The Artifact has been tested with the following images
*Debian 9 "Stretch"
*Ubuntu 16.04
*CentOS 7.4
