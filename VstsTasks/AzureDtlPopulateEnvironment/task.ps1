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
    [string] $EnvironmentParameterFile,
    [string] $EnvironmentParameterOverrides,
    [string] $EnvironmentTemplateOutputVariables,
    [string] $LocalTemplateName,
    #[string] $LocalParameterFile,,
    [string] $StoreEnvironmentTemplate,
    [string] $StoreEnvironmentTemplateLocation,
    [string] $EnvironmentTemplateLocationVariable,
    [string] $EnvironmentTemplateSasTokenVariable,
    [string] $LocalParameterOverrides,
    [string] $LocalTemplateOutputVariables
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
[string] $ArtifactsLocationName = '_artifactsLocation'
[string] $ArtifactsLocationSasTokenName = '_artifactsLocationSasToken'

try
{
    $OptionalParameters = @{}

    Write-Host 'Starting Azure DevTest Labs Create and Populate Environment Task'

    Show-InputParameters
    
    $parameterSet = Get-ParameterSet -templateId $TemplateId -path $EnvironmentParameterFile -overrides $EnvironmentParameterOverrides

    #$OptionalParameter = ConvertTo-Optionals -overrideParameters $LocalParameterOverrides
    if ($LocalParameterOverrides -ne $null) {
        $splitEntries = $LocalParameterOverrides.Split("-")
        #$hashtable = @{}

        foreach ($entry in $splitEntries) {
            if ($entry -ne "") {
                Write-Host "entry: $entry"
                $OptionalParameters.Add($($entry.Split(" ",2)[0]),$($entry.Split(" ",2)[1]))
            }
        }   
    }
    
    
    Write-Host "Opt: $($OptionalParameters)"

    Show-TemplateParameters -templateId $TemplateId -parameters $parameterSet

    $environmentResourceId = New-DevTestLabEnvironment -labId $LabId -templateId $TemplateId -environmentName $EnvironmentName -environmentParameterSet $parameterSet

    Write-Host "A: $environmentResourceId"

    $environmentResourceGroupId = Get-DevTestLabEnvironmentResourceGroupId -environmentResourceId $environmentResourceId

    Write-Host "B: $environmentResourceGroupId"

    $environmentResourceGroupName = $environmentResourceGroupId.Split('/')[4]
    Write-Host "C: $environmentResourceGroupName"

    $environmentResourceGroupLocation = Get-DevTestLabEnvironmentResourceGroupLocation -environmentResourceId $environmentResourceId
    Write-Host "D: $environmentResourceGroupLocation"
    
    #Create storage and copy files up
    $StorageContainerName = $environmentResourceGroupName.ToLowerInvariant() + '-stageartifacts'
    $StorageAccountName = 'stage' + ((Get-AzureRmContext).Subscription.SubscriptionId).Replace('-', '').substring(0, 19)
    $StorageAccount = New-AzureRmStorageAccount -StorageAccountName $StorageAccountName -Type 'Standard_LRS' -ResourceGroupName $environmentResourceGroupName -Location $environmentResourceGroupLocation
    Write-Host "E1: $($StorageAccount.StorageAccountName) "
    New-AzureStorageContainer -Name $StorageContainerName -Context $StorageAccount.Context -ErrorAction SilentlyContinue *>&1

    Write-Host "E2: $StorageContainerName"

    $localRootDir = Split-Path $LocalTemplateName
    $rootFile = Split-Path $LocalTemplateName -Leaf

    Write-Host "F: $localRootDir F1: $rootFile"
    
    $localFilePaths = Get-ChildItem $localRootDir -Recurse -File | ForEach-Object -Process {$_.FullName}
    
    Write-Host "F3: $localFilePaths"

    foreach ($SourcePath in $localFilePaths) {
        Write-Host "F3a: $SourcePath"
        Set-AzureStorageBlobContent -File $SourcePath -Blob $SourcePath.Substring($localRootDir.length + 1) `
            -Container $StorageContainerName -Context $StorageAccount.Context -Force
        Write-Host "F3b: $SourcePath"
    }
    Write-Host "F4: $($StorageAccount.Context.BlobEndPoint)"
    Write-Host "F4a: $StorageContainerName"
    $OptionalParameters.Set_Item($ArtifactsLocationName, $($StorageAccount.Context.BlobEndPoint + $StorageContainerName))
    Write-Host "G: $($OptionalParameters.$ArtifactsLocationName)"

    # Generate a 4 hour SAS token for the artifacts location if one was not provided in the parameters file    
    
    $OptionalParameters.Set_Item($ArtifactsLocationSasTokenName, $(New-AzureStorageContainerSASToken -Container $StorageContainerName -Context $StorageAccount.Context -Permission r -ExpiryTime (Get-Date).AddHours(4)))
    
    Write-Host "H: $($OptionalParameters.$ArtifactsLocationSasTokenName)"

    $storageFile = $StorageAccount.Context.BlobEndPoint + $StorageContainerName + "/" + $rootFile + $OptionalParameters.$ArtifactsLocationSasTokenName
    
    Write-Host "H1: $storageFile"
    Write-Host "H2: $OptionalParameters"
    #if ($LocalParameterFile -ne $null) {
        $localDeploymentOutput = New-AzureRmResourceGroupDeployment -ResourceGroupName $environmentResourceGroupName -TemplateFile $storageFile -TemplateParameterObject $OptionalParameters -Force -Mode Incremental
    #} else {
    #    $localDeploymentOutput = New-AzureRmResourceGroupDeployment -ResourceGroupName $environmentResourceGroupName -TemplateFile $storageFile -TemplateParameterFile $LocalParameterFile -Force
    #}
                                                                              
    Write-Host "I: $localDeploymentOutput"
    Write-Host "Z: Remove storage"
    Remove-AzureRmStorageAccount -ResourceGroupName $environmentResourceGroupName -Name $StorageAccountName -Force
    Write-Host "Post Remove"
        
    if ([System.Xml.XmlConvert]::ToBoolean($EnvironmentTemplateOutputVariables))
    {
        $environmentDeploymentOutput = [hashtable] (Get-DevTestLabEnvironmentOutput -environmentResourceId $environmentResourceId) 
        $environmentDeploymentOutput.Keys | ForEach-Object {
            if(Test-DevTestLabEnvironmentOutputIsSecret -templateId $TemplateId -key $_) {
                Write-Host "##vso[task.setvariable variable=$_;isSecret=true;isOutput=true;]$($environmentDeploymentOutput[$_])"
            } else {
                Write-Host "##vso[task.setvariable variable=$_;isSecret=false;isOutput=true;]$($environmentDeploymentOutput[$_])"
            }   
        }

        Write-Host "Completed Output information."

        if ([System.Xml.XmlConvert]::ToBoolean($StoreEnvironmentTemplate)) {

            $EnvironmentSasToken = $environmentDeploymentOutput["$EnvironmentTemplateSasTokenVariable"]
            $EnvironmentLocation = $environmentDeploymentOutput["$EnvironmentTemplateLocationVariable"]
            
            if (($EnvironmentLocation -eq "") -or ($EnvironmentSasToken -eq "")) {
                Write-Host "Missing Environment Location or Environment SAS token as outputs."
            }

            Write-Host "Parse Environment information."

            $tempEnvLoc = $EnvironmentLocation.Split("/")
            $storageAccountName = $tempEnvLoc[2].Split(".")[0]
            $containerName = $tempEnvLoc[3]
            $dtlPrefix = "$($tempEnvLoc[4])/$($tempEnvLoc[5])"

            $context = New-AzureStorageContext -StorageAccountName $storageAccountName -SasToken $EnvironmentSasToken

            $blobs = Get-AzureStorageBlob -Container $containerName -Context $context -Prefix $dtlPrefix

            New-Item -ItemType Directory -Force -Path $StoreEnvironmentTemplateLocation | Out-Null
            
            Write-Host "Downloading Azure templates"
            
            foreach ($blob in $blobs)
                {		            
                    $shortName = $($blob.Name.TrimStart($dtlPrefix))

                    if ($shortName.Contains("/")) {
                        New-Item -ItemType Directory -Force -Path "$StoreEnvironmentTemplateLocation\$($shortName.Substring(0,$shortName.IndexOf("/")))"
                    }

                    Get-AzureStorageBlobContent `
                    -Container $containerName -Blob $blob.Name -Destination "$StoreEnvironmentTemplateLocation\$shortName" `
		            -Context $context | Out-Null
      
                }
            Write-Host "Azure RM templates stored."

        }

    }
    if ([System.Xml.XmlConvert]::ToBoolean($LocalTemplateOutputVariables))
    {
        $secondaryDeploymentOutput = [hashtable] (Get-AzureRmResourceGroupDeployment -ResourceGroupName $environmentResourceGroupName -Name $localDeploymentOutput.DeploymentName) 
        $secondaryDeploymentOutput.Keys | ForEach-Object {
            #if(Test-DevTestLabEnvironmentOutputIsSecret -templateId $TemplateId -key $_) {
            #    Write-Host "##vso[task.setvariable variable=$_;isSecret=true;isOutput=true;]$($environmentDeploymentOutput[$_])"
            #} else {
                Write-Host "##vso[task.setvariable variable=$_;isSecret=false;isOutput=true;]$($secondaryDeploymentOutput[$_])"
            #}   
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
