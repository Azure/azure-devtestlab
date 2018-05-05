<##################################################################################################

    Description
    ===========

	Create a custom image based on the given parameters.

    Coming soon / planned work
    ==========================

    - N/A.    

##################################################################################################>
#
# Parameters to this script file.
#

[CmdletBinding()]
param(
    [string]$ConnectedServiceName,
    [string]$LabId,
    [string]$NewCustomImageName,
    [string]$Description,
    [string]$SourceLabVMId,
    [string]$OsType,
    [string]$LinuxOsState,
    [string]$WindowsOsState,
    [string]$OutputResourceId
)

###################################################################################################
#
# Required modules.
#

Import-Module Microsoft.TeamFoundation.DistributedTask.Task.Common
Import-Module Microsoft.TeamFoundation.DistributedTask.Task.Internal

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
    Write-Host 'Starting Azure DevTest Labs Create Custom Image Task'
    
    Show-InputParameters

    $lab = Get-AzureDtlLab -LabId "$LabId"

    $resource = Invoke-AzureDtlTask -Lab $lab

    if ($OutputResourceId)
    {
        # Capture the resource ID in the output variable.
        Write-Host "Creating variable '$OutputResourceId' with value '$($resource.Outputs.`"$OutputResourceId`".Value)'"
        Set-TaskVariable -Variable $OutputResourceId -Value "$($resource.Outputs.`"$OutputResourceId`".Value)"
    }

    Write-Host 'Completing Azure DevTest Labs Create Custom Image Task'
}
finally
{
    popd
}
