[CmdletBinding()]
param(
    [parameter(Mandatory = $true, ValueFromPipelineByPropertyName = $true)]
    [ValidateNotNullOrEmpty()]
    [string] $CsvConfigFile,

    [parameter(Mandatory = $false, ValueFromPipelineByPropertyName = $true)]
    [switch] $Force
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
Write-Host "Executing Lab Account Deletion Script, starting at $scriptstartTime" -ForegroundColor Green

$configObjects = $CsvConfigFile | Import-Csv
$labAccounts = $configObjects | Select-Object -Property ResourceGroupName, LabAccountName -Unique

$labaccounts | ForEach-Object {
    $labAccount = Get-AzLabAccount -ResourceGroupName $_.ResourceGroupName -LabAccountName $_.LabAccountName -ErrorAction SilentlyContinue
    if ($labAccount) {
        $labAccount | Remove-AzLabAccount
        Write-Host "Initiated removing Lab account '$($_.LabAccountName)' in resource group '$($_.ResourceGroupName)'"
    }
    else {
        Write-Host "Lab account '$($_.LabAccountName)' in resource group '$($_.ResourceGroupName)' doesn't exist, cannot delete..."
    }
}

Write-Host "Completed running Lab Account deletion, total duration $([math]::Round(((Get-Date) - $scriptstartTime).TotalMinutes, 1)) minutes" -ForegroundColor Green
