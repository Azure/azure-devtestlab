param
(
    [Parameter(Mandatory=$true, HelpMessage="The name of the DevTest Lab to clean up")]
    [string] $DevTestLabName
)

$ErrorActionPreference = 'Stop'

$modulePath = Join-Path (Split-Path ($Script:MyInvocation.MyCommand.Path)) "DistributionHelpers.psm1"
Import-Module $modulePath

$sourceLab = Find-AzureRmResource -ResourceType 'Microsoft.DevTestLab/labs' | Where-Object { $_.Name -eq $DevTestLabName}

if(!$sourceLab)
{
    Write-Error "Unable to find a lab named $DevTestLabName in $((Get-AzureRmContext).Subscription.Name)"
}

$labStorageInfo = GetLabStorageInfo $sourceLab
GetImageInfosForLab $DevTestLabName | Sort-Object -Property osType, imagePath | Select-Object -Property imageName, imagePath, osType, timestamp
