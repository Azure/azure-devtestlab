[CmdletBinding()]
param(
    [parameter(Mandatory = $true, ValueFromPipelineByPropertyName = $true)]
    [string]
    $CsvConfigFile,

    [parameter(Mandatory = $false, ValueFromPipelineByPropertyName = $true)]
    [int]
    $ThrottleLimit = 7
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

# Make sure the input file does exist
if (-not (Test-Path -Path $CsvConfigFile)) {
    Write-Error "Input CSV File must exist, please choose a valid file location..."
}

Import-Module ../../Az.LabServices.psm1 -Force
Import-Module ../Az.LabServices.BulkOperations.psm1 -Force

$scriptstartTime = Get-Date
Write-Host "Executing Bulk Lab deletion Script, starting at $scriptstartTime" -ForegroundColor Green

$CsvConfigFile | Import-Csv | Remove-AzLabsBulk -ThrottleLimit $ThrottleLimit

Write-Host "Completed running Bulk Lab deletion Script, total duration $([math]::Round(((Get-Date) - $scriptstartTime).TotalMinutes, 1)) minutes" -ForegroundColor Green