<#
.SYNOPSIS 
    This script deletes the Azure virtual machines with the passed Ids in the DevTest Lab.

.DESCRIPTION
    This script deletes the Azure virtual machines with the passed Ids in the DevTest Lab. It will
    process all VMs in parallel divided into blocks.

.PARAMETER ids
    Mandatory. Resource ids for the VMs to delete.

.PARAMETER profilePath
    Optional. Path to file with Azure Profile. How to generate this file is explained at the end of the Readme for the repo (https://github.com/lucabol/University).
    Default "$env:APPDATA\AzProfile.txt".

.EXAMPLE
    Remove-AzureDtlLabVMs -ids $vms

.NOTES

#>
[cmdletbinding()]
param
(
    [Parameter(Mandatory = $true, HelpMessage = "Resource ids for the VMs to delete")]
    [string[]] $ids,
    
    [Parameter(Mandatory = $false, HelpMessage = "Path to file with Azure Profile")]
    [string] $profilePath = "$env:APPDATA\AzProfile.txt"
)

trap {
    # NOTE: This trap will handle all errors. There should be no need to use a catch below in this
    #       script, unless you want to ignore a specific error.
    Handle-LastError
}

. .\Common.ps1

function DeleteSingleVM() {
    
    [CmdletBinding()]
    param
    (
        [Parameter(Mandatory = $true, HelpMessage = "Resource id for the VM to delete")]
        [string] $id, 
        
        [Parameter(Mandatory = $false, HelpMessage = "Path to file with Azure Profile")]
        [string] $profilePath = "$env:APPDATA\AzProfile.txt"
    )

    try {
        $azVer = GetAzureModuleVersion
        
        if ($azVer -ge "3.8.0") {
            Save-AzureRmContext -Path $global:profilePath | Write-Verbose
        }
        else {
            Save-AzureRmProfile -Path $global:profilePath | Write-Verbose
        }

        $name = $id.Split('/')[-1]
        Write-Verbose "Removing virtual machine $name ..."
        Remove-AzureRmResource -Force -ResourceId "$id" | Out-Null
        Write-Verbose "Done Removing $name ."
    } catch {
        $posMessage = $_.ToString() + "`n" + $_.InvocationInfo.PositionMessage
        Write-Error "`nERROR: $posMessage" -ErrorAction "Continue"
    }
}

$deleteVmBlock = {
    param($id, $profilePath)

    DeleteSingleVM -id $id -profilePath $profilePath
}

try {

    LogOutput "Start Removal"

    $credentialsKind = InferCredentials
    LogOutput "Credentials: $credentialsKind"

    LoadAzureCredentials -credentialsKind $credentialsKind -profilePath $profilePath

    $jobs = @()

    foreach ($id in $ids) {
        if ($credentialsKind -eq "File") { 
            LogOutput "Starting job to delete $id ..."
            $jobs += Start-Job -Name $id -ScriptBlock $deleteVmBlock -ArgumentList $id, $profilePath
            LogOutput "$id deleted."
        }
        else {
            DeleteSingleVM -id $id -profilePath $profilePath
        }
    }
    if ($credentialsKind -eq "File") {
        Wait-Job -Job $jobs | Write-Verbose
    }
    LogOutput "VM Deletion jobs have completed"

} finally {
    if ($credentialsKind -eq "File") {
        1..3 | % { [console]::beep(2500, 300) } # Make a sound to indicate we're done.
    }
    popd    
}
