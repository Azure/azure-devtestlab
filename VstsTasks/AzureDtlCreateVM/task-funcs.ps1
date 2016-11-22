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
    Write-Host "  TemplateName = $TemplateName"
    Write-Host "  TemplateParameters = $TemplateParameters"
    Write-Host "  OutputResourceId = $OutputResourceId"
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
    $templateFile = $TemplateName
    if (-not [IO.Path]::IsPathRooted($TemplateName))
    {
        $templateFile = Join-Path "$PSScriptRoot" "$TemplateName"
    }
    if (Test-Path "$templateFile")
    {
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
    }
    else
    {
        throw "Unable to locate template file '$TemplateName'. Make sure the template file exists or the path is correctly specified."
    }
    $templateParameterObject = ConvertTo-TemplateParameterObject -TemplateParameters "$TemplateParameters"

    Test-AzureRmResourceGroupDeployment -ResourceGroupName "$resourceGroupName" -TemplateFile "$templateFile" -TemplateParameterObject $templateParameterObject

    return New-AzureRmResourceGroupDeployment -Name "$deploymentName" -ResourceGroupName "$resourceGroupName" -TemplateFile "$templateFile" -TemplateParameterObject $templateParameterObject
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