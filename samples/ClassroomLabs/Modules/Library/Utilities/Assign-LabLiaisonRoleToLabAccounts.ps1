[CmdletBinding()]
param(
    [parameter(Mandatory = $true, ValueFromPipelineByPropertyName = $true)]
    [ValidateNotNullOrEmpty()]
    [string] $CsvConfigFile,

    [parameter(Mandatory = $false, ValueFromPipelineByPropertyName = $true)]
    [int] $ThrottleLimit = 10,

    [parameter(Mandatory = $false, ValueFromPipelineByPropertyName = $true)]
    [switch] $CreateCustomRole,

    [parameter(Mandatory = $false)]
    [string] $RoleDefinitionName = "Lab Services Liaison"
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

# Make sure the input file does exist
if (-not (Test-Path -Path $CsvConfigFile)) {
    Write-Error "Input CSV File must exist, please choose a valid file location..."
}
Import-Module ../Az.LabServices.psm1 -Force
Import-Module ../BulkOperations/Az.LabServices.BulkOperations.psm1 -Force

$scriptstartTime = Get-Date
Write-Host "Assigning $RoleDefinitionName to lab accounts, starting at $scriptstartTime" -ForegroundColor Green

if ($CreateCustomRole) {
    # We assume the defaults:  Current Subscription, Role Name = "Lab Services Liaison"
    . .\Import-LabLiaisonRole.ps1 -RoleDefinitionName $RoleDefinitionName
}

$CsvConfigFile | Import-Csv | Set-AzRoleToLabAccountsBulk -RoleDefinitionName $RoleDefinitionName

Write-Host "Completed running Bulk Lab Account Creation script, total duration $([math]::Round(((Get-Date) - $scriptstartTime).TotalMinutes, 1)) minutes" -ForegroundColor Green