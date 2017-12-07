function Handle-LastError
{
    [CmdletBinding()]
    param(
    )

    $message = $error[0].Exception.Message
    if ($message)
    {
        Write-Error "`n$message"
    }
}

function Invoke-AzureDtlTask
{
    [CmdletBinding()]
    param(
        $Lab,
        [string] $TemplateName,
        [string] $TemplateParameters
    )

    $null = @(
        Write-Host "Preparing deployment parameters"
    )
    $deploymentName = "Dtl$([Guid]::NewGuid().ToString().Replace('-', ''))"
    $resourceGroupName = $Lab.ResourceGroupName
    $templateFile = Get-TemplateFile -TemplateName $TemplateName
    if (-not $TemplateParameters.Contains('-labName'))
    {
        $TemplateParameters = "-labName '$($Lab.Name)' $TemplateParameters"
    }
    $null = @(
        Write-Host "Invoking deployment with the following parameters:"
        Write-Host "  DeploymentName = $deploymentName"
        Write-Host "  ResourceGroupName = $resourceGroupName"
        Write-Host "  TemplateFile = $templateFile"
        Write-Host "  TemplateParameters = $TemplateParameters"
    )
    $templateParameterObject = ConvertTo-TemplateParameterObject -TemplateParameters "$TemplateParameters"

    Test-AzureRmResourceGroupDeployment -ResourceGroupName "$resourceGroupName" -TemplateFile "$templateFile" -TemplateParameterObject $templateParameterObject

    return New-AzureRmResourceGroupDeployment -Name "$deploymentName" -ResourceGroupName "$resourceGroupName" -TemplateFile "$templateFile" -TemplateParameterObject $templateParameterObject
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

function Get-AzureDtlLab
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

function Get-AzureDtlDeploymentTargetResourceId
{
    [CmdletBinding()]
    param(
        [string] $DeploymentName,
        [string] $ResourceGroupName
    )
    
    [Array] $operations = Get-AzureRmResourceGroupDeploymentOperation -DeploymentName $DeploymentName -ResourceGroupName $ResourceGroupName

    foreach ($op in $operations)
    {
        if ($op.properties.targetResource -ne $null)
        {
            $targetResource = $op.properties.targetResource
            break
        }
    }

    if ([string]::IsNullOrEmpty($targetResource.id))
    {
        $null = @(
            Write-Host "Dumping resource group deployment operation details for $ResourceGroupName/$DeploymentName`:"
            Write-Host (ConvertTo-Json $operations)
        )

        throw "Unable to extract the target resource from operations for $ResourceGroupName/$DeploymentName"
    }

    return $targetResource.id
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
}

function Validate-InputParameters
{
    [CmdletBinding()]
    Param(
        [string] $TemplateParameters
    )

    Write-Host 'Validating input parameters'

    $templateParameterObject = ConvertTo-TemplateParameterObject -TemplateParameters "$TemplateParameters"

    # Only required for backward compatibility with earlier versions of the task.
    Validate-TemplateParameters -TemplateParameterObject $templateParameterObject

    $vmName = $templateParameterObject.Item('newVMName')
    Validate-VMName -Name "$vmName"
}

function Validate-ArtifactStatus
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
            $vm = Get-AzureRmResource -ResourceId $ResourceId -ODataQuery '$expand=Properties($expand=Artifacts)'
            [array]$artifacts = $vm.Properties.artifacts
            [array]$failedArtifacts = $artifacts | ? { $_.status -eq 'Failed' }
            [array]$succeededArtifacts = $artifacts | ? { $_.status -eq 'Succeeded' }
            if ($failedArtifacts.Count -gt 0 -or $succeededArtifacts.Count -lt $expectedArtifactsCount)
            {
                foreach ($failedArtifact in $failedArtifacts)
                {
                    $failedArtifactName = $failedArtifact.artifactId.split('/')[-1]

                    # Adding ##[warning] at the beginning of the line helps highlight it in VSTS build/release logs.
                    Write-Host "##[warning]Failed to apply artifact '$failedArtifactName'."

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

function Validate-TemplateParameters
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
        Write-Host 'WARNING: -newVMName value should be replaced with non-default.'
        $mustReplaceDefaults = $true
    }
    if ($userName -and $userName.Contains($defaultValues.UserName))
    {
        Write-Host 'WARNING: -userName value should be replaced with non-default.'
        $mustReplaceDefaults = $true
    }
    if ($password -and $password.Contains($defaultValues.Password))
    {
        Write-Host 'WARNING: -password value should be replaced with non-default.'
        $mustReplaceDefaults = $true
    }

    if ($mustReplaceDefaults)
    {
        throw 'Default values must be replaced. Please review the Template Parameters and modify as needed.'
    }
}

function Validate-VMName
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
