function Invoke-AzureDtlTask
{
    [CmdletBinding()]
    param(
        [string] $DeploymentName,
        [string] $ResourceGroupName,
        [string] $TemplateName,
        $TemplateParameterObject
    )

    $null = @(
        Write-Host "Preparing deployment parameters"
    )
    $templateFile = Get-TemplateFile -TemplateName $TemplateName

    $null = @(
        Write-Host "Invoking deployment with the following parameters:"
        Write-Host "  DeploymentName = $DeploymentName"
        Write-Host "  ResourceGroupName = $ResourceGroupName"
        Write-Host "  TemplateFile = $templateFile"
        Write-Host ('  TemplateParameters = ' + ($TemplateParameterObject.GetEnumerator() | sort -Property Key | % { "-$($_.Key) '$(if ($_.Value.GetType().Name -eq 'Hashtable') { ConvertTo-Json $_.Value -Compress } else { $_.Value })'" }))
    )

    Test-AzureRmResourceGroupDeployment -ResourceGroupName "$ResourceGroupName" -TemplateFile "$templateFile" -TemplateParameterObject $TemplateParameterObject

    return New-AzureRmResourceGroupDeployment -Name "$DeploymentName" -ResourceGroupName "$ResourceGroupName" -TemplateFile "$templateFile" -TemplateParameterObject $TemplateParameterObject
}

function ConvertTo-Bool
{
    [CmdletBinding()]
    param(
        [string] $Value
    )

    [bool] $boolValue = $false

    $null = [bool]::TryParse($Value, [ref]$boolValue)

    return $boolValue
}

function ConvertTo-Int
{
    [CmdletBinding()]
    param(
        [string] $Value
    )

    [int] $intValue = 0

    $null = [int]::TryParse($Value, [ref]$intValue)

    return $intValue
}

function ConvertTo-MinutesString
{
    [CmdletBinding()]
    param(
        [string] $Value
    )

    return "$Value minute$(if ($Value -ne 1){ 's' })"
}

function ConvertTo-TemplateParameterObject
{
    [CmdletBinding()]
    Param(
        [string] $TemplateParameters
    )

    # The following regular expression is used to extract a parameter that is defined following PS rules.
    #
    # For example, given the following parameters:
    #
    #    -newVMName '$(Build.BuildNumber)' -userName '$(User.Name)' -password (ConvertTo-SecureString -String '$(User.Password)' -AsPlainText -Force)
    #
    # the regular expression can be used to match newName, userName, password, etc.
    $pattern = '\-(?<k>\w+)\s+(?<v>[''"].*?[''"]|\(.*?\))'
    $pattern2 = '\-String\s+(?<v>[''"]?.*?[''"])'

    $templateParameterObject = @{}

    $null = @(
        [regex]::Matches($TemplateParameters, $pattern) | % {
            $value = $_.Groups[2].Value.Trim("`"'")
            $m = [regex]::Match($value, $pattern2)
            if ($m.Success)
            {
                $value = $m.Groups[1].Value.Trim("`"'")
            }
            $templateParameterObject[$_.Groups[1].Value] = $value
        }
    )

    return $templateParameterObject
}

function Get-DeploymentTargetResourceId
{
    [CmdletBinding()]
    param(
        [string] $DeploymentName,
        [string] $ResourceGroupName
    )

    [Array] $operations = Get-AzureRmResourceGroupDeploymentOperation -DeploymentName $DeploymentName -ResourceGroupName $ResourceGroupName

    foreach ($op in $operations)
    {
        if ($null -ne $op.properties.targetResource)
        {
            $targetResource = $op.properties.targetResource
            break
        }
    }

    if ([string]::IsNullOrEmpty($targetResource.id))
    {
        $null = @(
            Write-Host "##vso[task.logissue type=warning;]Dumping resource group deployment operation details for deployment '$DeploymentName' in resource group name '$ResourceGroupName'`:"
            Write-Host (ConvertTo-Json $operations)
        )

        throw "Unable to extract the target resource from operations for deployment '$DeploymentName' in resource group name '$ResourceGroupName'."
    }

    return $targetResource.id
}

function Get-DtlLab
{
    [CmdletBinding()]
    param(
        [string] $LabId
    )

    $null = @(
        $labParts = $LabId.Split('/')
        $labName = $labParts.Get($labParts.Length - 1)
        Write-Host "Fetching lab '$labName'"
    )

    return Get-AzureRmResource -ResourceId "$LabId"
}

function Get-DtlLabVm
{
    [CmdletBinding()]
    param(
        [string] $ResourceId
    )

    $vm = Get-AzureRmResource -ResourceId "$ResourceId"
    if (-not $vm)
    {
        throw "Unable to find VM with resource ID '$ResourceId'."
    }

    $vmName = $vm.Name
    if ($vm.ResourceName)
    {
        $vmLabName = $vm.ResourceName.Split('/')[0]
        $vmFullName = $vm.ResourceName
    }
    else
    {
        $vmLabName = $(if ($vm.ParentResource){ $vm.ParentResource.Split('/')[-1] } else { $null })
        $vmFullName = $(if ($vmLabName){ "$vmLabName/$vmName" } else { $vmName })
    }
    $vmResourceGroupName = $vm.ResourceGroupName
    $vmResourceType = $vm.ResourceType

    $vmDetails = Get-AzureRmResource -ApiVersion '2018-10-15-preview' -Name $vmFullName -ResourceGroupName $vmResourceGroupName -ResourceType $vmResourceType -ODataQuery '$expand=Properties($expand=Artifacts)'
    if (-not $vmDetails)
    {
        throw "Unable to get details for VM '$vmName' under lab '$vmLabName' and resource group '$vmResourceGroupName'."
    }

    return $vmDetails
}

function Get-ExpectedArtifactsCount
{
    [CmdletBinding()]
    param(
        [string] $ArmTemplateJson
    )

    $armTemplateObject = ConvertFrom-Json $ArmTemplateJson
    $vmTemplate = $armTemplateObject.resources | ? { $_.type -eq 'Microsoft.DevTestLab/labs/virtualmachines' } | Select-Object -First 1

    return $vmTemplate.properties.artifacts.Count
}

function Get-TemplateFile
{
    [CmdletBinding()]
    param(
        [string] $TemplateName
    )

    $templateFile = $TemplateName

    if (-not [IO.Path]::IsPathRooted($TemplateName))
    {
        $templateFile = Join-Path "$PSScriptRoot" "$TemplateName"
    }

    if (-not (Test-Path "$templateFile"))
    {
        throw "Unable to locate template file '$TemplateName'. Make sure the template file exists or the path is correctly specified."
    }

    return $templateFile
}

function Remove-FailedResourcesBeforeRetry
{
    [CmdletBinding()]
    param(
        [string] $DeploymentName,
        [string] $ResourceGroupName,
        [string] $DeleteLabVM,
        [string] $DeleteDeployment
    )

    try
    {
        # Delete the failed lab VM.
        if (ConvertTo-Bool -Value $DeleteLabVM)
        {
            $resourceId = Get-DeploymentTargetResourceId -DeploymentName $DeploymentName -ResourceGroupName $ResourceGroupName
            if ($resourceId)
            {
                Write-Host "Removing previously created lab virtual machine with resource ID '$resourceId'."
                Remove-AzureRmResource -ResourceId $resourceId -Force | Out-Null
            }
            else
            {
                Write-Host "Resource identifier is not available, will not attempt to remove corresponding resouce before retrying."
            }
        }

        # Delete the failed deployment.
        if (ConvertTo-Bool -Value $DeleteDeployment)
        {
            Write-Host "Removing previously created deployment '$DeploymentName' in resource group '$ResourceGroupName'."
            Remove-AzureRmResourceGroupDeployment -Name $DeploymentName -ResourceGroupName $ResourceGroupName | Out-Null
        }
    }
    catch
    {
        Write-Host "##vso[task.logissue type=warning;]Unable to clean-up failed resources. Operation failed with $($Error[0].Exception.Message)"
    }
}

function Show-InputParameters
{
    [CmdletBinding()]
    param(
    )

    Write-Host "Task called with the following parameters:"
    Write-Host "  ConnectedServiceName = $ConnectedServiceName"
    Write-Host "  LabId = $LabId"
    Write-Host "  TemplateName = $TemplateName"
    Write-Host "  TemplateParameters = $TemplateParameters"
    Write-Host "  OutputResourceId = $OutputResourceId"
    Write-Host "  FailOnArtifactError = $FailOnArtifactError"
    Write-Host "  RetryOnFailure = $RetryOnFailure"
    Write-Host "  RetryCount = $RetryCount"
    Write-Host "  DeleteFailedLabVMBeforeRetry = $DeleteFailedLabVMBeforeRetry"
    Write-Host "  DeleteFailedDeploymentBeforeRetry = $DeleteFailedDeploymentBeforeRetry"
    Write-Host "  AppendRetryNumberToVMName = $AppendRetryNumberToVMName"
    Write-Host "  WaitMinutesForApplyArtifacts = $WaitMinutesForApplyArtifacts"
}

function Test-ArtifactsInstalling
{
    [CmdletBinding()]
    param(
        [array] $Artifacts
    )

    [array]$installingArtifacts = $artifacts | ? { $_.status -eq 'Installing' }
    [array]$pendingArtifacts = $artifacts | ? { $_.status -eq 'Pending' }

    return $installingArtifacts.Count -gt 0 -or $pendingArtifacts.Count -gt 0
}

function Test-ArtifactStatus
{
    [CmdletBinding()]
    param(
        [string] $ResourceId,
        [string] $TemplateName,
        [string] $Fail
    )

    $checkForFailedArtifacts = ConvertTo-Bool -Value $Fail
    if ($checkForFailedArtifacts)
    {
        $templateFile = Get-TemplateFile -TemplateName $TemplateName
        # Read the contents of the ARM template and remove any comments of the form /* ... */,
        # since these cause the call to ConvertFrom-Json, later on, to fail.
        $armTemplateJson = [IO.File]::ReadAllText($templateFile) -replace '/\*(.|[\r\n])*?\*/',''
        $expectedArtifactsCount = Get-ExpectedArtifactsCount -ArmTemplateJson $armTemplateJson
        if ($expectedArtifactsCount -gt 0)
        {
            $vm = Get-DtlLabVm -ResourceId $ResourceId

            [array]$artifacts = $vm.Properties.artifacts
            [array]$failedArtifacts = $artifacts | ? { $_.status -eq 'Failed' }
            [array]$succeededArtifacts = $artifacts | ? { $_.status -eq 'Succeeded' }

            Write-Host "Number of Artifacts Expected: $expectedArtifactsCount, Reported: $($artifacts.Count), Succeeded: $($succeededArtifacts.Count), Failed: $($failedArtifacts.Count)"

            if ($failedArtifacts.Count -gt 0 -or $succeededArtifacts.Count -lt $expectedArtifactsCount)
            {
                foreach ($failedArtifact in $failedArtifacts)
                {
                    $failedArtifactName = $failedArtifact.artifactId.split('/')[-1]

                    Write-Host "##vso[task.logissue type=warning;]Failed to apply artifact '$failedArtifactName'."

                    if (-not [string]::IsNullOrEmpty($failedArtifact.deploymentStatusMessage))
                    {
                        # Using a try/catch when converting from JSON, as the returned text may be plain.
                        try
                        {
                            $deploymentStatusMessage = (ConvertFrom-Json $failedArtifact.deploymentStatusMessage).error.details.message
                        }
                        catch
                        {
                            $deploymentStatusMessage = $failedArtifact.deploymentStatusMessage
                        }
                        Write-Host "deploymentStatusMessage = $deploymentStatusMessage"
                    }

                    if (-not [string]::IsNullOrEmpty($failedArtifact.vmExtensionStatusMessage))
                    {
                        # Using a try/catch when converting from JSON, as the returned text may be plain.
                        try
                        {
                            $vmExtensionStatusMessage = (ConvertFrom-Json $failedArtifact.vmExtensionStatusMessage)[1].message
                        }
                        catch
                        {
                            $vmExtensionStatusMessage = $failedArtifact.vmExtensionStatusMessage
                        }
                        Write-Host "vmExtensionStatusMessage = $($vmExtensionStatusMessage -replace '\\n','')"
                    }
                }

                throw 'At least one artifact failed to apply. Review the lab virtual machine artifact results blade for full details.'
            }
        }
    }
}

function Test-InputParameters
{
    [CmdletBinding()]
    Param(
        $TemplateParameterObject
    )

    Write-Host 'Validating input parameters'

    # Only required for backward compatibility with earlier versions of the task.
    Test-TemplateParameters -TemplateParameterObject $TemplateParameterObject

    $vmName = $TemplateParameterObject.Item('newVMName')
    Test-VirtualMachineName -Name "$vmName"
}

function Test-TemplateParameters
{
    [CmdletBinding()]
    Param(
        $TemplateParameterObject
    )

    $defaultValues = @{
        NewVMName = '<Enter VM Name>'
        UserName = '<Enter User Name>'
        Password = '<Enter User Password>'
    }

    $vmName = $TemplateParameterObject.Item('newVMName')
    $userName = $TemplateParameterObject.Item('userName')
    $password = $TemplateParameterObject.Item('password')

    $mustReplaceDefaults = $false
    if ($vmName -and $vmName.Contains($defaultValues.NewVMName))
    {
        Write-Host "##vso[task.logissue type=warning;]-newVMName value should be replaced with non-default."
        $mustReplaceDefaults = $true
    }
    if ($userName -and $userName.Contains($defaultValues.UserName))
    {
        Write-Host "##vso[task.logissue type=warning;]-userName value should be replaced with non-default."
        $mustReplaceDefaults = $true
    }
    if ($password -and $password.Contains($defaultValues.Password))
    {
        Write-Host "##vso[task.logissue type=warning;]-password value should be replaced with non-default."
        $mustReplaceDefaults = $true
    }

    if ($mustReplaceDefaults)
    {
        throw 'Default values must be replaced. Please review the Template Parameters and modify as needed.'
    }
}

function Test-VirtualMachineName
{
    [CmdletBinding()]
    Param(
        [string] $Name,
        [int] $MaxNameLength = 15
    )

    if ([string]::IsNullOrWhiteSpace($Name))
    {
        throw "Invalid VM name '$Name'. Name must be specified."
    }

    if ($Name.Length -gt $MaxNameLength)
    {
        throw "Invalid VM name '$Name'. Name must be between 1 and $MaxNameLength characters."
    }

    $regex = [regex]'^(?=.*[a-zA-Z/-]+)[0-9a-zA-Z/-]*$'
    if (-not $regex.Match($Name).Success)
    {
        throw "Invalid VM name '$Name'. Name cannot be entirely numeric and cannot contain most special characters."
    }
}

function Wait-ApplyArtifacts
{
    [CmdletBinding()]
    param(
        [string] $ResourceId,
        [string] $WaitMinutes
    )

    $maxWaitMinutes = ConvertTo-Int -Value $WaitMinutes
    if ($maxWaitMinutes -gt 0)
    {
        Write-Host "Waiting for a maximum of $(ConvertTo-MinutesString $maxWaitMinutes) for apply artifacts operation to complete."

        $totalWaitMinutes = 0
        [string] $provisioningState
        $startWait = [DateTime]::Now
        $continueWaiting = $true
        do {
            $waitspan = New-TimeSpan -Start $startWait -End ([DateTime]::Now)
            $totalWaitMinutes = [Math]::Round($waitspan.TotalMinutes)
            $expired = $waitspan.TotalMinutes -ge $maxWaitMinutes
            if ($expired)
            {
                throw "Waited for more than $(ConvertTo-MinutesString $totalWaitMinutes). Failing the task."
            }

            $vm = Get-DtlLabVm -ResourceId $ResourceId

            $provisioningState = $vm.Properties.provisioningState
            $continueWaiting = Test-ArtifactsInstalling -Artifacts $vm.Properties.artifacts

            if ($continueWaiting)
            {
                # The only time we have seen we possibly need to wait is if the ARM deployment completed prematurely,
                # for some unknown error, and the virtual machine is still applying artifacts. So, it is reasonable to
                # recheck every 5 minutes.
                Start-Sleep -Seconds 300
            }
        } while ($continueWaiting)

        Write-Host "Waited for a total of $(ConvertTo-MinutesString $totalWaitMinutes). Latest provisioning state is $provisioningState."
    }
}