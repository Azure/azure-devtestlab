[CmdletBinding()]
param(
    [parameter(Mandatory = $true, ValueFromPipelineByPropertyName = $true)]
    [ValidateNotNullOrEmpty()]
    [string] $CsvConfigFile
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
Write-Host "Executing Add Student Script, starting at $scriptstartTime" -ForegroundColor Green

$objects = $CsvConfigFile | Import-LabsCsv 

foreach ($object in $objects) {

    $la = Get-AzLabAccount -ResourceGroupName $object.ResourceGroupName -LabAccountName $object.LabAccountName
    if (-not $la -or @($la).Count -ne 1) { Write-Error "Unable to find lab account $($object.LabAccountName)."}

    $lab = $la | Get-AzLab -LabName $object.LabName

    if ($lab) {
        Write-Host "Lab $($lab.Name) exists..  Adding students."

        if ($object.Emails) {
            Write-Host "Adding users for $($object.LabName) for users $($object.Emails)."
            $Lab | Add-AzLabUser -Emails $object.Emails | Out-Null
        }

    }
    
}

Write-Host "Completed running Bulk Lab Update Set Shared Password script, total duration $([math]::Round(((Get-Date) - $scriptstartTime).TotalMinutes, 1)) minutes" -ForegroundColor Green
