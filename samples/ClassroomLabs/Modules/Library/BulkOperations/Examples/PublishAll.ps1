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
Import-Module ../Az.LabServices.BulkOperations.psm1 -Force

$labAccountResults = $CsvConfigFile | 
        Import-LabsCsv |                                      # Import the CSV File into objects, including validation & transforms
        New-AzLabAccountsBulk -ThrottleLimit $ThrottleLimit | # Create all the lab accounts
        New-AzLabsBulk -ThrottleLimit $ThrottleLimit |        # Create all labs
        Publish-AzLabsBulk -ThrottleLimit $ThrottleLimit      # Publish all the labs

# Write out the results
$results | Select-Object -Property ResourceGroupName, LabAccountName, LabName, LabAccountResult, LabResult, PublishResult | Format-Table

Write-Host "Completed running Bulk Lab Creation script, total duration $(((Get-Date) - $outerScriptstartTime).TotalMinutes) minutes" -ForegroundColor Green
