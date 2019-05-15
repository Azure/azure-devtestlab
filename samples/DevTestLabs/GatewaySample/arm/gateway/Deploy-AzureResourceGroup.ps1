#Requires -Version 3.0
#Requires -Module AzureRM.Resources
#Requires -Module Azure.Storage

Param(
    [string] [Parameter(Mandatory = $true)] $ResourceGroupLocation,
    [string] [Parameter(Mandatory = $true)] $ResourceGroupName,
    [switch] $UploadArtifacts,
    [string] $StorageAccountName,
    [string] $StorageContainerName = $ResourceGroupName.ToLowerInvariant() + '-stageartifacts-' + (Get-Date).Ticks,
    [string] $TemplateFile = 'azuredeploy.json',
    [string] $TemplateParametersFile = 'azuredeploy.parameters.json',
    [string] $ArtifactStagingDirectory = '.',
    [string] $DSCSourceFolder = 'DSC',
    [switch] $ValidateOnly,
    [switch] $Reset,
    [switch] $Force
)

try {
    [Microsoft.Azure.Common.Authentication.AzureSession]::ClientFactory.AddUserAgent("VSAzureTools-$UI$($host.name)".replace(' ', '_'), '3.0.0')
}
catch { }

$ErrorActionPreference = 'Stop'
Set-StrictMode -Version 3

function Format-ValidationOutput {
    param ($ValidationOutput, [int] $Depth = 0)
    Set-StrictMode -Off
    return @($ValidationOutput | Where-Object { $_ -ne $null } | ForEach-Object { @('  ' * $Depth + ': ' + $_.Message) + @(Format-ValidationOutput @($_.Details) ($Depth + 1)) })
}

function Export-AzureRmContextFile {

    $ContextPath = [System.IO.Path]::ChangeExtension($PSCommandPath, '.ctx')
    if (Test-Path $ContextPath -PathType Leaf) { Remove-Item -Path $ContextPath -Force | Out-Null }

    $ContextClassic = [bool] (Get-Command -Name Save-AzureRmProfile -ErrorAction SilentlyContinue) # returns TRUE if AzureRM.profile version 2.7 or older is loaded
    if ($ContextClassic) { Save-AzureRmProfile -Path $ContextPath } else { Save-AzureRmContext -Path $ContextPath -Force }

    return $ContextPath
}

function Import-AzureRmContextFile {
    param(
        [string] $ContextPath = [System.IO.Path]::ChangeExtension($PSCommandPath, '.ctx')
    )

    $ContextClassic = [bool] (Get-Command -Name Select-AzureRMProfile -ErrorAction SilentlyContinue) # returns TRUE if AzureRM.profile version 2.7 or older is loaded
    if ($contextClassic) { Select-AzureRMProfile -Path $ContextPath } else { Import-AzureRmContext -Path $ContextPath }
}

$OptionalParameters = New-Object -TypeName Hashtable
$TemplateFile = [System.IO.Path]::GetFullPath([System.IO.Path]::Combine($PSScriptRoot, $TemplateFile))
$TemplateParametersFile = [System.IO.Path]::GetFullPath([System.IO.Path]::Combine($PSScriptRoot, $TemplateParametersFile))

if ($UploadArtifacts) {
    # Convert relative paths to absolute paths if needed
    $ArtifactStagingDirectory = [System.IO.Path]::GetFullPath([System.IO.Path]::Combine($PSScriptRoot, $ArtifactStagingDirectory))
    $DSCSourceFolder = [System.IO.Path]::GetFullPath([System.IO.Path]::Combine($PSScriptRoot, $DSCSourceFolder))

    # Parse the parameter file and update the values of artifacts location and artifacts location SAS token if they are present
    $JsonParameters = Get-Content $TemplateParametersFile -Raw | ConvertFrom-Json
    if (($JsonParameters | Get-Member -Type NoteProperty 'parameters') -ne $null) {
        $JsonParameters = $JsonParameters.parameters
    }

    $ArtifactsLocationName = '_artifactsLocation'
    $ArtifactsLocationSasTokenName = '_artifactsLocationSasToken'
    $OptionalParameters[$ArtifactsLocationName] = $JsonParameters | Select-Object -Expand $ArtifactsLocationName -ErrorAction Ignore | Select-Object -Expand 'value' -ErrorAction Ignore
    $OptionalParameters[$ArtifactsLocationSasTokenName] = $JsonParameters | Select-Object -Expand $ArtifactsLocationSasTokenName -ErrorAction Ignore | Select-Object -Expand 'value' -ErrorAction Ignore

    # Create DSC configuration archive
    if (Test-Path $DSCSourceFolder) {
        $DSCSourceFilePaths = @(Get-ChildItem $DSCSourceFolder -File -Filter '*.ps1' | ForEach-Object -Process {$_.FullName})
        foreach ($DSCSourceFilePath in $DSCSourceFilePaths) {
            $DSCArchiveFilePath = $DSCSourceFilePath.Substring(0, $DSCSourceFilePath.Length - 4) + '.zip'
            Publish-AzureRmVMDscConfiguration $DSCSourceFilePath -OutputArchivePath $DSCArchiveFilePath -Force -Verbose
        }
    }

    # Create a storage account name if none was provided
    if ($StorageAccountName -eq '') {
        $StorageAccountName = 'stage' + ((Get-AzureRmContext).Subscription.Id).Replace('-', '').substring(0, 19)
    }

    $StorageAccount = (Get-AzureRmStorageAccount | Where-Object {$_.StorageAccountName -eq $StorageAccountName})

    # Create the storage account if it doesn't already exist
    if ($StorageAccount -eq $null) {
        $StorageResourceGroupName = 'ARM_Deploy_Staging'
        New-AzureRmResourceGroup -Location "$ResourceGroupLocation" -Name $StorageResourceGroupName -Force
        $StorageAccount = New-AzureRmStorageAccount -StorageAccountName $StorageAccountName -Type 'Standard_LRS' -ResourceGroupName $StorageResourceGroupName -Location "$ResourceGroupLocation"
    }

    # Generate the value for artifacts location if it is not provided in the parameter file
    if ($OptionalParameters[$ArtifactsLocationName] -eq $null) {
        $OptionalParameters[$ArtifactsLocationName] = $StorageAccount.Context.BlobEndPoint + $StorageContainerName
    }

    # Copy files from the local storage staging location to the storage account container
    New-AzureStorageContainer -Name $StorageContainerName -Context $StorageAccount.Context -ErrorAction SilentlyContinue *>&1

    $ArtifactFilePaths = Get-ChildItem $ArtifactStagingDirectory -Recurse -File | ForEach-Object -Process {$_.FullName}
    foreach ($SourcePath in $ArtifactFilePaths) {
        Set-AzureStorageBlobContent -File $SourcePath -Blob $SourcePath.Substring($ArtifactStagingDirectory.length + 1) `
            -Container $StorageContainerName -Context $StorageAccount.Context -Force
    }

    # Generate a 4 hour SAS token for the artifacts location if one was not provided in the parameters file
    if ($OptionalParameters[$ArtifactsLocationSasTokenName] -eq $null) {
        $OptionalParameters[$ArtifactsLocationSasTokenName] = ConvertTo-SecureString -AsPlainText -Force `
        (New-AzureStorageContainerSASToken -Container $StorageContainerName -Context $StorageAccount.Context -Permission r -ExpiryTime (Get-Date).AddHours(4))
    }
}

if ($Reset -and (Get-AzureRmResourceGroup -Name $ResourceGroupName -Location $ResourceGroupLocation -ErrorAction SilentlyContinue)) {

    if ($Force) { Get-AzureRmResourceGroupDeployment -ResourceGroupName $ResourceGroupName | ? { $_.ProvisioningState -eq "Running" } | Stop-AzureRmResourceGroupDeployment | Out-Null }

    $location = Get-AzureRmLocation | ? { $ResourceGroupLocation -in ($_.Location, $_.DisplayName) } | select -First 1 -ExpandProperty Location

    if ((Get-AzureRmResourceGroup -Name $ResourceGroupName | select -First 1).Location -eq $location) {

        $context = Export-AzureRmContextFile

        try {
            
            $jobs = (Get-AzureRmResourceGroupDeployment -ResourceGroupName $ResourceGroupName | % {

                Start-Job -Name $_.DeploymentName -ScriptBlock {
                    param([string] $ctx, [string] $rgName, [string] $depName)
                    $ContextClassic = [bool] (Get-Command -Name Select-AzureRMProfile -ErrorAction SilentlyContinue)
                    if  ($ContextClassic) { Select-AzureRMProfile -Path $ctx } else { Import-AzureRmContext -Path $ctx }
                    Remove-AzureRmResourceGroupDeployment -ResourceGroupName $rgName -Name $depName -Verbose | Out-Null
                } -ArgumentList ($context, $ResourceGroupName, $_.DeploymentName)

            })

            if ($jobs) {

                Write-Output "Delete existing deployments ..."
                $jobs | Wait-Job | Out-Null
                $jobs | % { Write-Output "- $($_.Name)" }
            }
        }
        finally {

            Remove-Item -Path $context -Force -ErrorAction SilentlyContinue | Out-Null
        }

        $resetDeploymentName = 'azurereset-' + ((Get-Date).ToUniversalTime()).ToString('MMdd-HHmm')
        $resetTemplateFile = Join-Path $PSScriptRoot "azurereset.json"
    
        if (Test-Path -Path $resetTemplateFile -PathType Leaf ) {
    
            New-AzureRmResourceGroupDeployment -Name $resetDeploymentName `
                -ResourceGroupName $ResourceGroupName `
                -TemplateFile $resetTemplateFile
                -TemplateParameterUri "https://raw.githubusercontent.com/Azure/azure-quickstart-templates/master/100-blank-template/azuredeploy.parameters.json" `
                -Force -Verbose -Mode Complete
    
        } else {
    
            New-AzureRmResourceGroupDeployment -Name $resetDeploymentName `
                -ResourceGroupName $ResourceGroupName `
                -TemplateUri "https://raw.githubusercontent.com/Azure/azure-quickstart-templates/master/100-blank-template/azuredeploy.json" `
                -TemplateParameterUri "https://raw.githubusercontent.com/Azure/azure-quickstart-templates/master/100-blank-template/azuredeploy.parameters.json" `
                -Force -Verbose -Mode Complete
        }

    } else {

        Remove-AzureRmResourceGroup -Name $ResourceGroupName -Force -Verbose | Out-Null
    } 
    
}

# Create or update the resource group using the specified template file and template parameters file
New-AzureRmResourceGroup -Name $ResourceGroupName -Location $ResourceGroupLocation -Verbose -Force

if ($ValidateOnly) {
    $ErrorMessages = Format-ValidationOutput (Test-AzureRmResourceGroupDeployment -ResourceGroupName $ResourceGroupName `
            -TemplateFile $TemplateFile `
            -TemplateParameterFile $TemplateParametersFile `
            @OptionalParameters)
    if ($ErrorMessages) {
        Write-Output '', 'Validation returned the following errors:', @($ErrorMessages), '', 'Template is invalid.'
    }
    else {
        Write-Output '', 'Template is valid.'
    }
}
else {

    if ($Force) { Get-AzureRmResourceGroupDeployment -ResourceGroupName $ResourceGroupName | ? { $_.ProvisioningState -eq "Running" } | Stop-AzureRmResourceGroupDeployment | Out-Null }

    $deploymentResult = $null # captures the deployment result

    New-AzureRmResourceGroupDeployment -Name ((Get-ChildItem $TemplateFile).BaseName + '-' + ((Get-Date).ToUniversalTime()).ToString('MMdd-HHmm')) `
        -ResourceGroupName $ResourceGroupName `
        -TemplateFile $TemplateFile `
        -TemplateParameterFile $TemplateParametersFile `
        @OptionalParameters `
        -Force -Verbose `
        -ErrorVariable ErrorMessages | Tee-Object -Variable deploymentResult
                                    
    if ($ErrorMessages) {

        Write-Output '', 'Template deployment returned the following errors:', @(@($ErrorMessages) | ForEach-Object { $_.Exception.Message.TrimEnd("`r`n") })
    
    }
    else {

        if (-not (Get-Module AzureRm.Profile)) {
            Import-Module AzureRm.Profile
        }

        $azureRmProfileModuleVersion = (Get-Module AzureRm.Profile).Version
        if ($azureRmProfileModuleVersion.Major -ge 3) {
            $azureRmProfile = [Microsoft.Azure.Commands.Common.Authentication.Abstractions.AzureRmProfileProvider]::Instance.Profile
        }
        else {
            $azureRmProfile = [Microsoft.WindowsAzure.Commands.Common.AzureRmProfileProvider]::Instance.Profile
        }

        $profileClient = New-Object Microsoft.Azure.Commands.ResourceManager.Common.RMProfileClient($azureRmProfile)
        $token = $profileClient.AcquireAccessToken((Get-AzureRmContext).Subscription.TenantId) 
        $functionName = $deploymentResult.Outputs.functionName.Value

        $retry = 0

		#Getting function key
        while ($true) {
            try {

                #Eforce TLS 1.2 for communication - otherwise both rest method calls will fail
                [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12

                $masterKey = (Invoke-RestMethod -Uri "https://$functionName.scm.azurewebsites.net/api/functions/admin/masterkey" -Headers @{"Authorization" = "Bearer $($token.AccessToken)"}) | select -ExpandProperty masterkey
                $hostKeys = (Invoke-RestMethod -Uri "https://$functionName.azurewebsites.net/admin/host/keys?code=$masterKey" -UseBasicParsing) | select -ExpandProperty keys
                $defaultKey = $hostKeys | ? { $_.name -eq "default" } | select -First 1 -ExpandProperty value

                Write-Output "API Key: $defaultKey"
                break
            }
            catch {
                if ($retry++ -lt 10) {
                    Write-Warning ($_.Exception.Message + " (waiting for retry $retry)")
                    Start-Sleep -Seconds 30
                }
                else {
                    throw
                }
            }            
        }
    }
}
