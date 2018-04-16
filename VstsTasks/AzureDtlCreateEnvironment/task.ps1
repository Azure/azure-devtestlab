<##################################################################################################

    Description
    ===========

    Create a Lab Environment using the provided ARM template.

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
    [string] $RepositoryId,
    [string] $TemplateId,
    [string] $EnvironmentName,
    [string] $ParameterFile,
    [string] $ParameterOverrides,
    [string] $OutputEnvironmentResourceId,
    [string] $OutputEnvironmentResourceGroupId,
    [string] $TemplateOutputImport,
    [string] $TemplateOutputPrefix
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

[string] $environmentResourceId = ''
[string] $environmentResourceGroupId = ''

try
{
    Write-Host 'Starting Azure DevTest Labs Create Environment Task'

    Show-InputParameters

    $parameterSet = Get-ParameterSet -templateId $TemplateId -path $ParameterFile -overrides $ParameterOverrides

    $environmentResourceId = New-DevTestLabEnvironment -labId $LabId -templateId $TemplateId -environmentName $EnvironmentName -environmentParameterSet $parameterSet
    $environmentResourceGroupId = Get-DevTestLabEnvironmentResourceGroupId -environmentResourceId $environmentResourceId
    
    if ([System.Xml.XmlConvert]::ToBoolean($TemplateOutputImport))
    {
        $environmentDeploymentOutput = [hashtable] (Get-DevTestLabEnvironmentOutput -environmentResourceId $environmentResourceId -keyPrefix ("$TemplateOutputPrefix".Trim()))
        $environmentDeploymentOutput.Keys | % {

            Write-Host "Creating variable '$_' with value '$($environmentDeploymentOutput[$_])'"
            Set-TaskVariable -Variable $_ -Value "$($environmentDeploymentOutput[$_])"
        }
    }
}
finally
{
    if ($OutputEnvironmentResourceId -and -not [string]::IsNullOrWhiteSpace($environmentResourceId))
    {
        Write-Host "Creating variable '$OutputEnvironmentResourceId' with value '$environmentResourceId'"
        Set-TaskVariable -Variable $OutputEnvironmentResourceId -Value "$environmentResourceId"
    }

    if ($OutputEnvironmentResourceGroupId -and -not [string]::IsNullOrWhiteSpace($environmentResourceGroupId))
    {
        Write-Host "Creating variable '$OutputEnvironmentResourceGroupId' with value '$environmentResourceGroupId'"
        Set-TaskVariable -Variable $OutputEnvironmentResourceGroupId -Value "$environmentResourceGroupId"
    }

    Write-Host 'Completing Azure DevTest Labs Create Environment Task'
    Pop-Location
}
