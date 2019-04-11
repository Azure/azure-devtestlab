function Show-InputParameters {
    [CmdletBinding()]
    param(
    )

    Write-Host "Task called with the following parameters:"
    Write-Host "  ConnectedServiceName = $ConnectedServiceName"
    Write-Host "  LabId = $LabId"
    Write-Host "  EnvironmentId = $EnvironmentId"
}

function Get-DevTestLabContextUserId {
    [CmdletBinding()]
    param()

    [string] $userId = $((Get-AzureRmADUser -UserPrincipalName (Get-AzureRmContext).Account).Id.Guid)

    if ($userId) { return $userId }

    return [string] (Get-AzureRmADServicePrincipal -ServicePrincipalName ((Get-AzureRmContext).Account.Id -split '@')[0]).Id.Guid
}

function Remove-DevTestLabEnvironment {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string] $labId,
        [Parameter(Mandatory = $true)]
        [string] $environmentId,
        [Parameter(Mandatory = $false)]
        [string] $maxRetries = 5
    )

    $usr = Get-DevTestLabContextUserId 
    $lab = Get-AzureRmResource -ResourceId $labId
    $env = $null

    if (-not $environmentId.StartsWith($labId, [System.StringComparison]::InvariantCultureIgnoreCase)) {
        $env = Get-AzureRmResource -ResourceGroupName $lab.ResourceGroupName -ResourceType 'Microsoft.DevTestLab/labs/users/environments' -ResourceName "$($lab.Name)/$usr/$environmentId" -ApiVersion 2016-05-15 -ErrorAction SilentlyContinue | Select-Object -First 1
    }
    else {
        $env = Get-AzureRmResource -ResourceId $environmentId  -ApiVersion 2016-05-15 -ErrorAction SilentlyContinue
    }
    
    if ($env) {
        $retry = 0
        while (++$retry -le $maxRetries) {
            try {
                "Deleting environment '$($env.ResourceId)' ($retry/$maxRetries)"
                Remove-AzureRmResource -ResourceId $env.ResourceId -ApiVersion '2016-05-15' -Force | Out-Null
                break
            }
            catch {
                if ($retry -eq $maxRetries) { throw $error[0].Exception.Message }
                Start-Sleep -Seconds 10
            }
        }
    }   
    else {
        throw "Could not find environment '$environmentId' in lab '$($lab.Name)' owned by user '$usr'."
    } 
}