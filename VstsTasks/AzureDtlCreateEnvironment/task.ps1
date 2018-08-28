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
    [string] $TemplateOutputVariables,
    [string] $StoreEnvironmentTemplate,
    [string] $StoreEnvironmentTemplateLocation,
    [string] $EnvironmentTemplateLocationVariable,
    [string] $EnvironmentTemplateSasTokenVariable
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

    Show-TemplateParameters -templateId $TemplateId -parameters $parameterSet
    
    $environmentResourceId = New-DevTestLabEnvironment -labId $LabId -templateId $TemplateId -environmentName $EnvironmentName -environmentParameterSet $parameterSet
    $environmentResourceGroupId = Get-DevTestLabEnvironmentResourceGroupId -environmentResourceId $environmentResourceId
    
    if ([System.Xml.XmlConvert]::ToBoolean($TemplateOutputVariables))
    {
        $environmentDeploymentOutput = [hashtable] (Get-DevTestLabEnvironmentOutput -environmentResourceId $environmentResourceId)
         
        $environmentDeploymentOutput.Keys | ForEach-Object {

            if(Test-DevTestLabEnvironmentOutputIsSecret -templateId $TemplateId -key $_) {
                Write-Host "##vso[task.setvariable variable=$_;isSecret=true;isOutput=true;]$($environmentDeploymentOutput[$_])"
            } else {
                Write-Host "##vso[task.setvariable variable=$_;isSecret=false;isOutput=true;]$($environmentDeploymentOutput[$_])"
            }   
        }

        if ([System.Xml.XmlConvert]::ToBoolean($StoreEnvironmentTemplate)) {
            #Test saving the template
            Write-Host "++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++"

            $EnvironmentSasToken = $environmentDeploymentOutput["$EnvironmentTemplateSasTokenVariable"]
            $EnvironmentLocation = $environmentDeploymentOutput["$EnvironmentTemplateLocationVariable"]

            Write-Host "loc: $EnvironmentLocation"
            Write-Host "sas: $EnvironmentSasToken"
            Write-Host "build: $StoreEnvironmentTemplateLocation"

            $tempEnvLoc = $EnvironmentLocation.Split("/")
            $storageAccountName = $tempEnvLoc[2].Split(".")[0]
            $containerName = $tempEnvLoc[3]

            Write-Host "store acct name: $storageAccountName"
            Write-Host "container Name: $containerName"

            $context = New-AzureStorageContext -StorageAccountName $storageAccountName -SasToken $EnvironmentSasToken

            Write-Host "Post Context"
        
            # !!!!! SasToken only has read permissions not list

            $blobs = Get-AzureStorageBlob -Container $containerName -Context $context

            Write-Host "Post Blobs: $($blobs.Length)"

            foreach ($blob in $blobs)
                {
		            #New-Item -ItemType Directory -Force -Path $destination_path
                    Write-Host "In Loop $blob"
                    Get-AzureStorageBlobContent `
                    -Container $containerName -Blob $blob.Name -Destination $StoreEnvironmentTemplateLocation `
		            -Context $context
      
                }

            Write-Host "++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++"
        }
    }
    

    
}
finally
{
    if (-not [string]::IsNullOrWhiteSpace($environmentResourceId))
    {
        Write-Host "##vso[task.setvariable variable=environmentResourceId;isSecret=false;isOutput=true;]$environmentResourceId"
    }

    if (-not [string]::IsNullOrWhiteSpace($environmentResourceGroupId))
    {
        Write-Host "##vso[task.setvariable variable=environmentResourceGroupId;isSecret=false;isOutput=true;]$environmentResourceGroupId"
    }

    Write-Host 'Completing Azure DevTest Labs Create Environment Task'
    Pop-Location
}
