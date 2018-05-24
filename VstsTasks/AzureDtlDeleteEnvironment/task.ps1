<##################################################################################################

    Description
    ===========

    Delete a Lab Environment using the provided ARM template.

    Coming soon / planned work
    ==========================

    - N/A.    

##################################################################################################>

#
# Parameters to this script file.
#

[CmdletBinding()]
param(
    [string] $ConnectedServiceName,
    [string] $LabId,
    [string] $EnvironmentId
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
Push-Location $PSScriptRoot

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

    $message = $error[0].Exception.Message
    
    if ($message) {
        Write-Error "`n$message"
    }
}

###################################################################################################

#
# Main execution block.
#

try
{
    Write-Host 'Starting Azure DevTest Labs Delete Environment Task'

    Show-InputParameters

    Remove-DevTestLabEnvironment -labId $LabId -environmentId $EnvironmentId
}
finally
{
    Write-Host 'Completing Azure DevTest Labs Delete Environment Task'
    Pop-Location
}
