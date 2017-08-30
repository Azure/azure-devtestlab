<#
.SYNOPSIS 
    Given LabName and LabSize, this script verifies how many Azure virtual machines are inside the DevTest Lab and throws an error inside the logs when the number is greater or lower than size +/- VMDelta. 

.DESCRIPTION
    Given LabName and LabSize, this script verifies how many Azure virtual machines are inside the DevTest Lab and throws an error inside the logs when the number is greater or lower than size +/- VMDelta. 

.PARAMETER LabName
    Mandatory. The name of the Dev Test Lab to run the test on.

.PARAMETER LabSize
    Mandatory. Number of VMs that should be in the lab.

.PARAMETER profilePath
    Optional. Path to file with Azure Profile. How to generate this file is explained at the end of the Readme for the repo (https://github.com/lucabol/University).
    Default "$env:APPDATA\AzProfile.txt".

.PARAMETER VMDelta
    Optional. Percentage of error in number of VMs (i.e. 0.1 means the lab can contain 10% more or less VMs).
    Default 0.1

.EXAMPLE
    Test-AzureDtlLabVMs -LabName University -LabSize 50

.NOTES

#>
[cmdletbinding()]
param
(
    [Parameter(Mandatory = $true, HelpMessage = "The name of the Dev Test Lab to clean up")]
    [string] $LabName,

    [Parameter(Mandatory = $false, HelpMessage = "Path to file with Azure Profile")]
    [string] $profilePath = "$env:APPDATA\AzProfile.txt",

    [Parameter(Mandatory = $true, HelpMessage = "Number of VMs that should be in the lab")]
    [int] $LabSize,

    [Parameter(Mandatory = $false, HelpMessage = "Percentage of error in number of VMs (i.e. 0.1 means the lab can contain 10% more or less VMs)")]
    [double] $VMDelta = 0.1    
)

trap {
    # NOTE: This trap will handle all errors. There should be no need to use a catch below in this
    #       script, unless you want to ignore a specific error.
    Handle-LastError
}

. .\Common.ps1

#### Main script

try {
    LogOutput "Start Testing Lab"

    $credentialsKind = InferCredentials

    LogOutput "Credentials: $credentialsKind"
    LoadAzureCredentials -credentialsKind $credentialsKind -profilePath $profilePath

    [array] $vms = GetAllLabVMsExpanded -LabName $LabName
    [array] $failedVms = $vms | ? { $_.Properties.provisioningState -eq 'Failed' }

    $vmCount = $vms.Count
    $failedCount = $failedVms.Count
    $availableVMs = $vmCount - $failedCount
    Write-Output "Total Number of VMs: $vmCount, Failed VMs: $failedCount, Available VMs: $availableVMs"

    $wrongCount = ($availableVMs -lt $LabSize * (1 - $VMDelta)) -or ($availableVMs -gt $LabSize * (1 + $VMDelta))
    $someFailed = $failedCount -ne 0

    if ($someFailed -or $wrongCount) {
        Write-Error "VMs count: $availableVMs / $LabSize, Failed VMs: $FailedCount"
    }
    else {
        Write-Output "The lab is as expected"
    }

} finally {
    if ($credentialsKind -eq "File") {
        1..3 | % { [console]::beep(2500, 300) } # Make a sound to indicate we're done.
    }
    popd
}
