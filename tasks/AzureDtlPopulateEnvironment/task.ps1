<##################################################################################################

    Description
    ===========

    Deploy an ARM template using an existing Lab Environment.

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
    [string] $EnvironmentId,
    [string] $SourceTemplate,
    [string] $SourceTemplateParameterFile,
    [string] $SourceTemplateParameterOverrides,
    [string] $SourceTemplateOutputVariables
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

[string] $ArtifactsLocationName = '_artifactsLocation'
[string] $ArtifactsLocationSasTokenName = '_artifactsLocationSasToken'

try
{
    $OptionalParameters = @{}

    Write-Host 'Starting Azure DevTest Labs deploy ARM template to Environment Task'

    Show-InputParameters
    
    # Get parameters overrides
    if ($SourceTemplateParameterOverrides -ne $null) {
        Write-Host "Getting parameters from input."

        $splitEntries = $SourceTemplateParameterOverrides.Split("-")

        foreach ($entry in $splitEntries) {
            if ($entry -ne "") {
                Write-Host "entry: $entry"
                $OptionalParameters.Add($($entry.Split(" ",2)[0]),$($entry.Split(" ",2)[1]))
            }
        }   
    }

    $environmentResourceGroupId = Get-DevTestLabEnvironmentResourceGroupId -environmentResourceId $EnvironmentId
    $environmentResourceGroupName = $environmentResourceGroupId.Split('/')[4]
    $environmentResourceGroupLocation = Get-DevTestLabEnvironmentResourceGroupLocation -environmentResourceId $EnvironmentId

    #Create storage and copy files up
    $StorageContainerName = $environmentResourceGroupName.ToLowerInvariant() + '-stageartifacts'
    $StorageAccountName = 'stage' + ((Get-AzureRmContext).Subscription.SubscriptionId).Replace('-', '').substring(0, 19)
    $StorageAccount = New-AzureRmStorageAccount -StorageAccountName $StorageAccountName -Type 'Standard_LRS' -ResourceGroupName $environmentResourceGroupName -Location $environmentResourceGroupLocation
    New-AzureStorageContainer -Name $StorageContainerName -Context $StorageAccount.Context -ErrorAction SilentlyContinue *>&1


    $localRootDir = Split-Path -Path $SourceTemplate
    $rootFile = Split-Path -Path $SourceTemplate -Leaf
    
    $localFilePaths = Get-ChildItem $localRootDir -Recurse -File | ForEach-Object -Process {$_.FullName}

    foreach ($SourcePath in $localFilePaths) {
        $blob = Set-AzureStorageBlobContent -File $SourcePath -Blob $SourcePath.Substring($localRootDir.length + 1) `
            -Container $StorageContainerName -Context $StorageAccount.Context -Force
    }
    
    $checkParameters = Get-Content -Raw -Path $SourceTemplate | ConvertFrom-Json

    if ($($checkParameters.parameters | Get-Member -MemberType NoteProperty | Select -ExpandProperty Name).Contains($ArtifactsLocationName)){
        # Get the storage location
        $OptionalParameters.Set_Item($ArtifactsLocationName, $($StorageAccount.Context.BlobEndPoint + $StorageContainerName))
    }

    if ($($checkParameters.parameters | Get-Member -MemberType NoteProperty | Select -ExpandProperty Name).Contains($ArtifactsLocationSasTokenName)){
        Write-Host "Include $ArtifactsLocationName Parameter."
        # Generate a 4 hour SAS token for the artifacts location if one was not provided in the parameters file    
        $OptionalParameters.Set_Item($ArtifactsLocationSasTokenName, $(New-AzureStorageContainerSASToken -Container $StorageContainerName -Context $StorageAccount.Context -Permission r -ExpiryTime (Get-Date).AddHours(4)))

        # Set the file to be deployed
        $storageFile = $StorageAccount.Context.BlobEndPoint + $StorageContainerName + "/" + $rootFile + $OptionalParameters.$ArtifactsLocationSasTokenName
    } else {
        Write-Host "Exclude Parameter"
        $storageFile = $StorageAccount.Context.BlobEndPoint + $StorageContainerName + "/" + $rootFile + $(New-AzureStorageContainerSASToken -Container $StorageContainerName -Context $StorageAccount.Context -Permission r -ExpiryTime (Get-Date).AddHours(4))
    }

    if ($(Test-Path -Path $SourceTemplateParameterFile -PathType Leaf )) {
        Write-Host "Deploy using parameter file."
        $localDeploymentOutput = New-AzureRmResourceGroupDeployment -ResourceGroupName $environmentResourceGroupName -TemplateFile $storageFile -TemplateParameterFile $SourceTemplateParameterFile -Force -Mode Incremental        
    } else {
        Write-Host "Deploy using parameter override."
        $localDeploymentOutput = New-AzureRmResourceGroupDeployment -ResourceGroupName $environmentResourceGroupName -TemplateFile $storageFile -TemplateParameterObject $OptionalParameters -Force -Mode Incremental
    }

    # Remove storage account                                                                      
    Remove-AzureRmStorageAccount -ResourceGroupName $environmentResourceGroupName -Name $StorageAccountName -Force

    # Set output to devops variables
    if ([System.Xml.XmlConvert]::ToBoolean($SourceTemplateOutputVariables))
    {
        $secondaryDeploymentOutput = [hashtable] (Get-AzureRmResourceGroupDeployment -ResourceGroupName $environmentResourceGroupName -Name $localDeploymentOutput.DeploymentName) 
        $secondaryDeploymentOutput.Keys | ForEach-Object {
        Write-Host "##vso[task.setvariable variable=$_;isSecret=false;isOutput=true;]$($secondaryDeploymentOutput[$_])"

        }
    }
}
finally
{
    Write-Host 'Completing Azure DevTest Labs Populate Environment Task'
    Pop-Location
}
