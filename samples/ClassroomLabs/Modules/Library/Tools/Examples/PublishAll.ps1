[CmdletBinding()]
param(
    [parameter(Mandatory = $true, ValueFromPipelineByPropertyName = $true)]
    [string]
    $CsvConfigFile,

    [parameter(Mandatory = $false, ValueFromPipelineByPropertyName = $true)]
    [int]
    $ThrottleLimit = 5
)

$outerScriptstartTime = Get-Date
Write-Host "Executing Lab Creation Script, starting at $outerScriptstartTime" -ForegroundColor Green

Import-Module ../../Az.LabServices.psm1 -Force
Import-Module ../LabCreationLibrary.psm1 -Force

$CsvConfigFile | Import-LabsCsv | Publish-Labs

Write-Host "Completed running Bulk Lab Creation script, total duration $(((Get-Date) - $outerScriptstartTime).TotalMinutes) minutes" -ForegroundColor Green