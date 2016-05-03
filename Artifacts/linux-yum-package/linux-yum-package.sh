#!/bin/bash
#
# Script to install packages on Azure DevTest lab Linux VMs via the yum package management system.
#
# NOTE: Intended for use by the Azure DevTest Lab artifact system.
#
# Usage: 
#
# linux-yum-package.sh --update (true|false) --packages (PACKAGE-LIST) --options [ADDITIONAL-OPTIONS]
#

# Default argument values
DEFAULT_UPDATE_MODE=0
ARGMODE_UPDATE=update
ARGMODE_PACKAGE=packages
ARGMODE_OPTIONS=options
ARGMODE_NONE=none
REQUIRED_INSTALL_OPTIONS="--assumeyes --quiet"
REQUIRED_UPDATE_OPTIONS="--assumeyes --quiet"
USAGE_STRING="Usage:
linux-yum-package.sh --update (true|false) --packages (package-list) --options (additional-options)

update
    Only specify true or false here. Default is false.

packages
    Specify packages to install separated by spaces. Follows the conventions of yum (see man yum for details).

options
    Specify any additional options you want to send to yum. These get injected prior to the install command.
    
NOTE: The additional options '$REQUIRED_INSTALL_OPTIONS' are always used for both update and install commands executed as a result of this script.
NOTE: No additional options are sent into the update command, if that option is specified.

"

LOGCMD='logger -i -t AZDEVTST_YUMPKG --'
which logger
if [ $? -ne 0 ] ; then
    LOGCMD='echo [AZDEVTST_YUMPKG] '
fi

$LOGCMD "Installing packages. Command line given:"
$LOGCMD "   $@"

# Check for minimum number of parameters first - must be at minimum 3
if [ $# -lt 3 ] ; then
  $LOGCMD "ERROR: This script needs at least 3 command-line arguments, update=, packages=[somepackagename], and options=."
  $LOGCMD "$USAGE_STRING"
  exit 1
fi  

ARGMODE=$ARGMODE_NONE

while :
do
    $LOGCMD "Argument mode: $ARGMODE. Argument being processed is '$1'"
    
    case "$1" in
        "--$ARGMODE_UPDATE")
            ARGMODE=$ARGMODE_UPDATE
            DO_GLOBAL_UPDATE=$DEFAULT_UPDATE_MODE
            shift
            $LOGCMD "Setting argmode to $ARGMODE. Setting the update mode to default ($DO_GLOBAL_UPDATE), checking for further arguments to set update mode."
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
                $ARGMODE_UPDATE)
                    $LOGCMD "Current update-before-install mode is $DO_GLOBAL_UPDATE. Argument recieved is '$1'."
                    if [ "$1" = "true" ] || [ "$1" = "yes" ] ; then
                        DO_GLOBAL_UPDATE=1
                    else
                        DO_GLOBAL_UPDATE=0
                    fi
                    $LOGCMD "Set update before install mode to $DO_GLOBAL_UPDATE."
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
                    $ADDITIONAL_OPTIONS = "$ADDITIONAL_OPTIONS $1"
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

set -e

if [ $DO_GLOBAL_UPDATE -eq 1 ] ; then
    $LOGCMD "Updating the system using yum update. Command line being used is: 'yum $REQUIRED_UPDATE_OPTIONS update'."
    yum $REQUIRED_UPDATE_OPTIONS update
    $LOGCMD "Update COMPLETED."
else
    $LOGCMD "Skipping yum update prior to package install."
fi

$LOGCMD "Installing packages using yum, using command line:"
$LOGCMD "  yum $ADDITIONAL_OPTIONS $REQUIRED_INSTALL_OPTIONS install $INSTALL_PACKAGES"
yum $ADDITIONAL_OPTIONS $REQUIRED_INSTALL_OPTIONS install $INSTALL_PACKAGES

set +e

$LOGCMD "Done installing packages"
