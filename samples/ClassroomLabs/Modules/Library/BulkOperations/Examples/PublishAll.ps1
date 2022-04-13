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

[System.Collections.ArrayList]$tracker = $CsvConfigFile | Import-LabsCsv
[System.Collections.ArrayList]$deployGroup = $null

While ($tracker.Count -ne 0) {
    $numVMs = 0
    $countLab = 0
    $notEnough = $true
    $deployGroup = @()
    while ($notEnough -and ($tracker.Count -ne 0)) {
        $numVMs += $tracker[$countLab].MaxUsers

        if ($numVMs -gt 300) {
            $notEnough = $false
        } else {
            Write-Host "Adding Lab $($tracker[$countLab].LabName) to be deployed"
            $deployGroup += $tracker[$countLab]
            #$countLab ++
            $tracker.Remove($tracker[$countLab]) | Out-Null
        }        
    }
    Write-Host "Creating and publishing labs with less than 300 vms."
    $results = $deployGroup | New-AzLabAccountsBulk -ThrottleLimit $deployGroup.Count | # Create all the lab accounts
    New-AzLabsBulk -ThrottleLimit $deployGroup.Count |        # Create all labs
    Publish-AzLabsBulk -ThrottleLimit $deployGroup.Count      # Publish all the labs

    $results | Select-Object -Property ResourceGroupName, LabAccountName, LabName, LabAccountResult, LabResult, PublishResult | Format-Table
}

#$labAccountResults = $CsvConfigFile | 
#        Import-LabsCsv |                                      # Import the CSV File into objects, including validation & transforms
#        New-AzLabAccountsBulk -ThrottleLimit $ThrottleLimit | # Create all the lab accounts
#        New-AzLabsBulk -ThrottleLimit $ThrottleLimit |        # Create all labs
#        Publish-AzLabsBulk -ThrottleLimit $ThrottleLimit      # Publish all the labs

# Write out the results
#$results | Select-Object -Property ResourceGroupName, LabAccountName, LabName, LabAccountResult, LabResult, PublishResult | Format-Table



Write-Host "Completed running Bulk Lab Creation script, total duration $(((Get-Date) - $outerScriptstartTime).TotalMinutes) minutes" -ForegroundColor Green
