function Handle-LastError {
    [CmdletBinding()]
    param(
    )

    $message = $error[0].Exception.Message
    if ($message) {
        Write-Error "`n$message"
    }
}

function ConvertTo-Array {
    [CmdletBinding()]
    param (
        [parameter(ValueFromPipeline)]
        $value,

        [switch] $RemoveNull,
        [switch] $RemoveEmpty
    )
    
    begin { 
        $array = @()
    }
    process {
        $skip = ($RemoveNull -and $value -eq $null) -or ($RemoveEmpty -and $value -eq "")
        if (-not $skip) { $array += $value }
    }
    end { 
        return , $array
    }
}

function Show-InputParameters {
    [CmdletBinding()]
    param(
    )

    Write-Host "Task called with the following parameters:"
    Write-Host "  ConnectedServiceName = $ConnectedServiceName"
    Write-Host "  LabId = $LabId"
    Write-Host "  RepositoryId = $RepositoryId"
    Write-Host "  TemplateId = $TemplateId"
    Write-Host "  EnvironmentName = $EnvironmentName"
    Write-Host "  ParameterFile = $ParameterFile"
    Write-Host "  ParameterOverrides = $ParameterOverrides"
    Write-Host "  OutputEnvironmentResourceId = $OutputEnvironmentResourceId"
    Write-Host "  OutputEnvironmentResourceGroupId = $OutputEnvironmentResourceGroupId"
}

function Get-ParameterSet {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [System.Uri] $path,
        [Parameter(Mandatory = $true)]
        [string] $templateId,
        [Parameter(Mandatory = $false)]
        [string] $overrides
    )

    if (Test-Path $path -PathType Leaf)
    {        
        $json = Get-Content -Path $path | Out-String    
    } 
    else 
    {
        $json = "{ `"parameters`": { } }"
    }
     
    $parameterSet = @{}
    $parameterObject = $json | ConvertFrom-Json

    if ($parameterObject | Get-Member -MemberType NoteProperty -Name parameters -ErrorAction SilentlyContinue) 
    {
        $parameterObject.parameters | Get-Member -MemberType NoteProperty | Select-Object -ExpandProperty Name | % {
            $parameterSet.Set_Item([string] $_, ($parameterObject.parameters | Select-Object -ExpandProperty $_).value)
        }
    }

    if ($overrides)
    {
        [regex]::Matches($override, '\-(?<k>\w+)\s+(?<v>[''"].*?[''"]|\(.*?\))') | % {
            $key = $_.Groups[1].Value
            $val = $_.Groups[2].Value.Trim("`"'")
            $parameterSet.Set_Item($key, $val)
        }
    }

    if ($parameterSet.Count -gt 0)
    {
        $template = Get-AzureRmResource -ResourceId $templateId
        $templateParameterNames = [string[]] (Get-Member -InputObject $template.Properties.contents.parameters -MemberType NoteProperty | Select-Object -ExpandProperty Name)

        # remove parameters not available in template
        $parameterSet.Keys | Where-Object { $_ -notin $templateParameterNames } | ConvertTo-Array | % { 
            Write-Host "Removing parameter '$_' from parameter list (not needed by environment template)."
            $parameterSet.Remove([string] $_) 
        }

        # removing parameters set by the lab
        ('_artifactsLocation', '_artifactsLocationSasToken') | ? { $parameterSet.ContainsKey([string] $_) } | % { 
            Write-Host "Removing parameter '$_' from parameter list (parameter value will provided by lab)."
            $parameterSet.Remove([string] $_) 
        } 
    }

    return $parameterSet
}

function Get-DevTestLabContextUserId {
    [CmdletBinding()]
    param(
    )

    [string] $userId = $((Get-AzureRmADUser -UserPrincipalName (Get-AzureRmContext).Account).Id.Guid)

    if ($userId) { return $userId }

    return [string] (Get-AzureRmADServicePrincipal -ServicePrincipalName ((Get-AzureRmContext).Account.Id -split '@')[0]).Id.Guid
}

function New-DevTestLabEnvironment {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string] $labId,
        [Parameter(Mandatory = $true)]
        [string] $templateId,
        [Parameter(Mandatory = $true)]
        [string] $environmentName,
        [Parameter(Mandatory = $true)]
        [hashtable] $environmentParameterSet
    )

    $userId = Get-DevTestLabContextUserId

    $templateParameters = $environmentParameterSet.Keys | ForEach-Object { 
        if ($environmentParameterSet[$_] -is [array]) {
            @{ "name" = "$_"; "value" = "$($environmentParameterSet[$_] | ConvertTo-Json -Compress)" } 
        }
        else {
            @{ "name" = "$_"; "value" = "$($environmentParameterSet[$_])" } 
        }
    } | ConvertTo-Array

    $templateProperties = @{ "deploymentProperties" = @{ "armTemplateId" = "$templateId"; "parameters" = $templateParameters }; } 

    $lab = Get-AzureRmResource -ResourceId $labId
    $env = New-AzureRmResource -Location $Lab.Location -ResourceGroupName $lab.ResourceGroupName -Properties $templateProperties -ResourceType 'Microsoft.DevTestLab/labs/users/environments' -ResourceName "$($lab.Name)/$userId/$environmentName" -ApiVersion '2016-05-15' -Force 

    return [string] $env.ResourceId
}

function Get-DevTestLabEnvironmentResourceGroupId {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string] $environmentResourceId
    )

    $environment = Get-AzureRmResource -ResourceId $environmentResourceId  -ApiVersion '2016-05-15'

    return [string] $environment.Properties.resourceGroupId
} 

function Get-DevTestLabEnvironmentResourceTags {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string] $environmentResourceGroupId
    )

    $splitOptions = [System.StringSplitOptions]::RemoveEmptyEntries

    $tagPattern = "hidden-DevTestLabs-Output:(.+)"
    $tags = @{}

    Get-AzureRmResource -ResourceId "$environmentResourceGroupId/resources" | select -ExpandProperty Tags -ErrorAction SilentlyContinue | ? { $_.Name -match $tagPattern } | % {
        $name = $Matches[1]
        $value = $_.Value
        $tags.Set_Item($name, $value)
    }

    return $tags
}