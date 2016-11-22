<##################################################################################################

    Description
    ===========

	Delete a Lab VM given its resource ID.

    Coming soon / planned work
    ==========================

    - N/A.    

##################################################################################################>

#
# Parameters to this script file.
#

[CmdletBinding()]
Param(
    [string]$ConnectedServiceName,
    [string]$LabVMId
)

###################################################################################################

#
# PowerShell configurations
#

# NOTE: Because the $ErrorActionPreference is "Stop", this script will stop on first failure.
#       This is necessary to ensure we capture errors inside the try-catch-finally block.
$ErrorActionPreference = "Stop"

# Ensure we set the working directory to that of the script.
pushd $PSScriptRoot

###################################################################################################

#
# Functions used in this script.
#

.".\task-funcs.ps1"

###################################################################################################

#
# Handle all errors in this script.
#

trap
{
    # NOTE: This trap will handle all errors. There should be no need to use a catch below in this
    #       script, unless you want to ignore a specific error.
    Handle-LastError
}

###################################################################################################

#
# Main execution block.
#

try
{
    Write-Host 'Starting Azure DevTest Labs Delete VM Task'

    Show-InputParameters

    Invoke-AzureDtlTask -LabVMId "$LabVMId"

    Write-Host 'Completing Azure DevTest Labs Delete VM Task'
}
finally
{
    popd
}
