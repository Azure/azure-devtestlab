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
    Write-Host "  TemplateOutputImport = $TemplateOutputImport"
    Write-Host "  TemplateOutputPrefix = $TemplateOutputPrefix"
}

function Get-ParameterSet {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string] $path,
        [Parameter(Mandatory = $true)]
        [string] $templateId,
        [Parameter(Mandatory = $false)]
        [string] $overrides
    )

    $parameterSet = @{}

    if (Test-Path $path -PathType Leaf) {
        Write-Host "Reading parameter file '$path' ..."
        $parameterObject = Get-Content -Path $path | Out-String | ConvertFrom-Json
        
        if ($parameterObject | Get-Member -MemberType NoteProperty -Name parameters -ErrorAction SilentlyContinue) {
            $parameterObject.parameters | Get-Member -MemberType NoteProperty | Select-Object -ExpandProperty Name | % {
                Write-Host "  Reading parameter '$_'"
                $parameterSet.Set_Item([string] $_, ($parameterObject.parameters | Select-Object -ExpandProperty $_).value)
            }
        } 
    }

    if ($overrides) {
        Write-Host "Reading override parameters ..."
        [regex]::Matches($overrides, '\-(?<k>\w+)\s+(?<v>[''"].*?[''"]|\(.*?\))') | % {
        
            $key = $_.Groups[1].Value
            $val = $_.Groups[2].Value.Trim("`"'")

            Write-Host "  Reading parameter '$key'"
            $parameterSet.Set_Item($key, $val)
        }
    }

    if ($parameterSet.Count) {

        Write-Host "Validating parameters ..."
        $template = Get-AzureRmResource -ResourceId $templateId -ApiVersion '2016-05-15'
        $templateParameterNames = [string[]] (Get-Member -InputObject $template.Properties.contents.parameters -MemberType NoteProperty | Select-Object -ExpandProperty Name)

        # remove parameters not available in template
        $parameterSet.Keys | Where-Object { $_ -notin $templateParameterNames } | ConvertTo-Array | % { 
            Write-Host "  Removing parameter '$_'"
            $parameterSet.Remove([string] $_) 
        }

        # removing parameters set by the lab
        ('_artifactsLocation', '_artifactsLocationSasToken') | ? { $parameterSet.ContainsKey([string] $_) } | % { 
            Write-Host "  Removing parameter '$_'"
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

    Write-Host "Environment properties: $($templateProperties | ConvertTo-Json -Depth 5 -Compress)"

    $lab = Get-AzureRmResource -ResourceId $labId
    $env = New-AzureRmResource -Location $lab.Location -ResourceGroupName $lab.ResourceGroupName -Properties $templateProperties -ResourceType 'Microsoft.DevTestLab/labs/users/environments' -ResourceName "$($lab.Name)/$userId/$environmentName" -ApiVersion '2016-05-15' -Force 

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

function Get-DevTestLabEnvironmentOutput {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string] $environmentResourceId,
        [Parameter(Mandatory = $false)]
        [string] $keyPrefix
    )

    $resourceGroupId = Get-DevTestLabEnvironmentResourceGroupId -environmentResourceId $environmentResourceId
    $resourceGroupName = Split-Path $resourceGroupId -Leaf

    $hashtable = @{}
    $deployment = Get-AzureRmResourceGroupDeployment -ResourceGroupName $resourceGroupName | Select-Object -Last 1

    if ($deployment -and $deployment.Outputs) {

        Write-Host "Reading template output ..."
        $deployment.Outputs.Keys | % {

            $key = "$keyPrefix$($_)"
            $val = $deployment.Outputs[$_].Value

            $hashtable.Set_Item($key, $val)
        }
    }

    return [hashtable] $hashtable
}