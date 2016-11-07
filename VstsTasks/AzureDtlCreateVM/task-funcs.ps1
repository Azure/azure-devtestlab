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

    return Invoke-Expression -Command "New-AzureRmResourceGroupDeployment -Name `"$deploymentName`" -ResourceGroupName `"$resourceGroupName`" -TemplateFile `"$templateFile`" $TemplateParameters"
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

function Get-TemplateParameterValue
{
    [CmdletBinding()]
    Param(
        [string]$Parameters,
        [string]$ParameterName
    )

    # The following regular expression is used to extract a parameter that is defined following PS rules.
    #
    # For example, given the following parameters:
    #
    #    -newVMName '$(Build.BuildNumber)' -userName '$(User.Name)' -password (ConvertTo-SecureString -String '$(User.Password)' -AsPlainText -Force)
    #
    # the regular expression can be used to match newName, userName, password, etc.

    $pattern = '\-(?<k>\w+)\s+(?<v>\''.*?\''|\$\(.*\)?|\(.*\)?)'

    $value = [regex]::Matches($Parameters, $pattern) | % { if ($_.Groups[1].Value -eq $ParameterName) { return $_.Groups[2].Value } }
    if ($value)
    {
        $value = $value.Trim("'")
    }
    
    return $value
}

function Validate-TemplateParameters
{
    [CmdletBinding()]
    Param(
        [string] $Parameters
    )

    $defaultValues = @{
        NewVMName = '<Enter VM Name>'
        UserName = '<Enter User Name>'
        Password = '<Enter User Password>'
    }

    $vmName = Get-TemplateParameterValue -Parameters $Parameters -ParameterName 'newVMName'
    $userName = Get-TemplateParameterValue -Parameters $Parameters -ParameterName 'userName'
    $password = Get-TemplateParameterValue -Parameters $Parameters -ParameterName 'password'

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
    $vmName = Get-TemplateParameterValue -Parameters "$TemplateParameters" -ParameterName 'newVMName'
    Validate-TemplateParameters -Parameters "$TemplateParameters"
    Validate-VMName -Name "$vmName"
}