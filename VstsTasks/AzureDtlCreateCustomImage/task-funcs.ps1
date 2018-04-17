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

function Show-InputParameters
{
    [CmdletBinding()]
    param(
    )

    Write-Host "Task called with the following parameters:"
    Write-Host "  ConnectedServiceName = $ConnectedServiceName"
    Write-Host "  LabId = $LabId"
    Write-Host "  NewCustomImageName = $NewCustomImageName"
    Write-Host "  Description = $Description"
    Write-Host "  SourceLabVMId = $SourceLabVMId"
    Write-Host "  OsType = $OsType"
    if ($OsType -eq 'Linux')
    {
        Write-Host "  LinuxOsState = $LinuxOsState"
    }
    elseif ($OsType -eq 'Windows')
    {
        Write-Host "  WindowsOsState = $WindowsOsState"
    }
    Write-Host "  OutputResourceId = $OutputResourceId"
}

function Invoke-AzureDtlTask
{
    [CmdletBinding()]
    param(
        $Lab
    )

    $null = @(
        Write-Host 'Preparing deployment parameters'
    )

    $deploymentName = "Dtl$([Guid]::NewGuid().ToString().Replace('-', ''))"
    $resourceGroupName = $lab.ResourceGroupName
    $templateFile = Join-Path "$PSScriptRoot" 'new-azuredtl-customimage.json'
    $templateParameterObject = Get-TemplateParameterObject

    $null = @(
        Write-Host 'Invoking deployment with the following parameters:'
        Write-Host "  DeploymentName = $deploymentName"
        Write-Host "  ResourceGroupName = $resourceGroupName"
        Write-Host "  TemplateFile = $templateFile"
        Write-Host ('  TemplateParameters = ' + ($templateParameterObject.GetEnumerator() | sort -Property Key | % { "-$($_.Key) '$(if ($_.Value.GetType().Name -eq 'Hashtable') { ConvertTo-Json $_.Value -Compress } else { $_.Value })'" }))
    )

    Test-AzureRmResourceGroupDeployment -ResourceGroupName "$resourceGroupName" -TemplateFile "$templateFile" -TemplateParameterObject $templateParameterObject

    return New-AzureRmResourceGroupDeployment -Name "$deploymentName" -ResourceGroupName "$resourceGroupName" -TemplateFile "$templateFile" -TemplateParameterObject $templateParameterObject
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
        $lab = Get-AzureRmResource -ResourceId "$LabId"
    )

    return $lab
}

function Get-TemplateParameterObject
{
    [CmdletBinding()]
    param(
    )

    $author = $Env:RELEASE_RELEASENAME
    $authorType = 'release'
    if ([string]::IsNullOrWhiteSpace($author))
    {
        $author = $Env:BUILD_BUILDNUMBER
        $authorType = 'build'
    }
    $requestedFor = $Env:RELEASE_REQUESTEDFOR
    if ([string]::IsNullOrWhiteSpace($requestedFor))
    {
        $requestedFor = $Env:BUILD_REQUESTEDFOR
    }
    if ([string]::IsNullOrWhiteSpace($Description))
    {
        $Description = "Custom image created from $authorType $author requested for $requestedFor."
    }

    $vmOsInfo = @{
        sourceVmId = $SourceLabVMId
    }

    if ($OsType -eq 'Linux')
    {
        $vmOsInfo += @{
            linuxOsInfo = @{
                linuxOsState = $LinuxOsState
            }
        }
    }
    elseif ($OsType -eq 'Windows')
    {
        $vmOsInfo += @{
            windowsOsInfo = @{
                windowsOsState = $WindowsOsState
            }
        }
    }

    $templateParameterObject = @{
        author = $author
        description = $Description
        labName = $lab.Name
        newCustomImageName = $NewCustomImageName
        vmOsInfo = $vmOsInfo
    }

    return $templateParameterObject
}
