#!/bin/bash
#
# Script to install NPM packages on Azure DevTest lab VMs.
#
# For each package requested to install, runs the currently installed
# npm to actually perform the install. Every package requested is either
# installed to the global system or to a specific local path on the VM.
#
# NOTE: Intended for use by the Azure DevTest Lab artifact system.
#
# Usage: 
#
# linux-npm-package.sh -packages (PACKAGE-LIST) --install-to (true|false) --options [ADDITIONAL-OPTIONS]
#

# Constants:
DEFAULT_INSTALL_GLOBAL=1
GLOBAL_SWITCH=""
INSTALL_TO="/var/tmp"
ARGMODE_INSTALLTO=install-to
ARGMODE_PACKAGE=packages
ARGMODE_OPTIONS=options
ARGMODE_NONE=none
REQUIRED_INSTALL_OPTIONS=""
USAGE_STRING="Usage:
linux-npm-package.sh --packages (package-list) --install-global (boolean) --options (additional-options)

packages
    Specify packages to install separated by spaces.

install-to 
    Path to install the packages to. If this isn't specified (or is given as an empty string/blank) then the packages
    are installed globally. Also, if the keyword 'global' is specified, the packages are installed globally as well.
    
options
    Specify any additional options you want to send to npm. All of these are appended to the end of the entire npm command.
    
NOTE: The additional options --quiet and --assume-yes are always used for both update and install commands executed as a result of this script.
NOTE: No additional options are sent into the update command, if that option is specified.

"

LOGCMD='logger -i -t AZDEVTST_NPMPKG --'
which logger
if [ $? -ne 0 ] ; then
    LOGCMD=echo
fi

$LOGCMD "Installing packages. Command line given:"
$LOGCMD "   $@"

# Check for minimum number of parameters first - must be at minimum 3
if [ $# -lt 3 ] ; then
  $LOGCMD "ERROR: This script needs at least 3 command-line arguments, update, packages, and options."
  $LOGCMD "$USAGE_STRING"
  exit 1
fi

which npm
if [ $? -ne 0 ] ; then
    $LOGCMD "ERROR: No npm found in path. Please install npm via apt, yum, or whichever package management system is available and re-run this artifact."
    exit 1
fi

ARGMODE=$ARGMODE_NONE

while :
do
    $LOGCMD "Argument mode: $ARGMODE. Argument being processed is '$1'"
    
    case "$1" in
        "--$ARGMODE_INSTALLTO")
            ARGMODE=$ARGMODE_INSTALLTO
            INSTALL_GLOBAL=$DEFAULT_INSTALL_GLOBAL
            shift
            $LOGCMD "Setting argmode to $ARGMODE. Setting the $ARGMODE_INSTALLTO mode to default ($INSTALL_GLOBAL), checking for further arguments to set $ARGMODE_INSTALLTO mode."
            ;;
        "--$ARGMODE_PACKAGE")
            ARGMODE=$ARGMODE_PACKAGE
            shift
            $LOGCMD "Setting argmode to $ARGMODE. Requirement to get packages begins."
            ;;
        "--$ARGMODE_OPTIONS")
            ARGMODE=$ARGMODE_OPTIONS
            shift
            ;;
        "")
	        $LOGCMD "Finished parsing through all command line arguments."
	        break
	        ;;
        *)
            case "$ARGMODE" in
                $ARGMODE_NONE)
                    $LOGCMD "WARNING: Parsing arguments while still in 'none' argument mode. Not supported, but we'll play along... Arg recieved is '$1'"
                    shift
                    ;;
                $ARGMODE_INSTALLTO)
                    $LOGCMD "Current $ARGMODE mode is $INSTALL_GLOBAL. Argument recieved is '$1'."
                    if [ "$1" = "global" ] ; then
                        INSTALL_GLOBAL=1
                    else
                        INSTALL_GLOBAL=0
                        INSTALL_TO="$1"
                        $LOGCMD "Setting install location to specified path '$INSTALL_TO'"
                    fi
                    $LOGCMD "Set update before install mode to $INSTALL_GLOBAL."
                    shift
                    ;;
                $ARGMODE_PACKAGE)
                    $LOGCMD "Current packages set to install are '$INSTALL_PACKAGES', adding argument received '$1'"
                    INSTALL_PACKAGES="$INSTALL_PACKAGES $1"
                    $LOGCMD "...packages to install is now '$INSTALL_PACKAGES'"
                    shift
                    ;;
                $ARGMODE_OPTIONS)
                    $LOGCMD "Current additional options set are $ADDITIONAL_OPTIONS, adding argument received '$1'"
                    ADDITIONAL_OPTIONS="$ADDITIONAL_OPTIONS $1"
                    $LOGCMD "...additional options is now '$ADDITIONAL_OPTIONS'"
                    shift
                    ;;
                *)
                    $LOGCMD "ERROR: Got into argument mode '$ARGMODE' somehow, not supported! Argument received is '$1'"
                    $LOGCMD "$USAGE_STRING"
                    exit 1
                    ;;
            esac
            ;;
    esac
done
$LOGCMD "Got Arguments: Install Globally='$INSTALL_GLOBAL' InstallLoc='$INSTALL_TO' Install Packages='$INSTALL_PACKAGES' Options='$ADDITIONAL_OPTIONS'"

# Determine if the package install is for global or local. If local, ensure
# the local path is available
if [ $INSTALL_GLOBAL -ne 1 ] ; then

    $LOGCMD "Testing if the local installation path '$INSTALL_TO' exists..."
    
    if [ ! -d "$INSTALL_TO" ] ; then
        $LOGCMD "...it does not, creating it:"
        
        mkdir -p "$INSTALL_TO"
        if [ $? -ne 0 ] ; then
            
            $LOGCMD "Could not make folder '$INSTALL_TO'. Failing process."
            
        fi
    else
    
        $LOGCMD "...it does exist."
    
    fi
    
    cd "$INSTALL_TO"

else

    GLOBAL_SWITCH="--global"
    
fi

# For each package named in the parameter list, install the package and log the 
# install command line for potential diagnosing later
arr=$(echo $PACKAGE_LIST | tr "," "\n")

set -e

$LOGCMD "Installing packages '$INSTALL_PACKAGES', using command line:"
$LOGCMD "npm install $GLOBAL_SWITCH \"$INSTALL_PACKAGES\" $ADDITIONAL_OPTIONS"
    
npm install $GLOBAL_SWITCH $INSTALL_PACKAGES $ADDITIONAL_OPTIONS
    
set +e

$LOGCMD "Done installing npm packages '$INSTALL_PACKAGES'."
