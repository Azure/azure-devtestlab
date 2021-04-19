[CmdletBinding()]
param(
    [parameter(Mandatory = $true, ValueFromPipelineByPropertyName = $true)]
    [ValidateNotNullOrEmpty()]
    [string] $CsvConfigFile,

    [parameter(Mandatory = $true, ValueFromPipelineByPropertyName = $true)]
    [ValidateNotNullOrEmpty()]
    [string] $CsvOutputFile,

    [parameter(Mandatory = $false, ValueFromPipelineByPropertyName = $true)]
    [int] $ThrottleLimit = 10,

    [parameter(Mandatory = $false, ValueFromPipelineByPropertyName = $true)]
    [ValidateSet('Created', 'Published')]
    [string]
    $ExpectedLabState = 'Created'
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

# Make sure the input file does exist
if (-not (Test-Path -Path $CsvConfigFile)) {
    Write-Error "Input CSV File must exist, please choose a valid file location..."
}

# Make sure the output file doesn't exist
if (Test-Path -Path $CsvOutputFile) {
    Write-Error "Output File cannot already exist, please choose a location to create a new output file..."
}

Import-Module ../../Az.LabServices.psm1 -Force
Import-Module ../Az.LabServices.BulkOperations.psm1 -Force

$scriptstartTime = Get-Date
Write-Host "Executing Lab validation Script, starting at $scriptstartTime" -ForegroundColor Green

$labs = $CsvConfigFile | Import-LabsCsv | Confirm-AzLabsBulk -ThrottleLimit $ThrottleLimit -ExpectedLabState $ExpectedLabState

$labs | Export-Csv -Path $CsvOutputFile -NoTypeInformation

Write-Host "Completed running validation script, total duration $([math]::Round(((Get-Date) - $scriptstartTime).TotalMinutes, 1)) minutes" -ForegroundColor Green
