<#
Prints out a report of all running VMs and asks confirmation to stop them.
#>
[CmdletBinding()]
param()

Import-Module ..\Az.LabServices.psm1 -Force

Write-Host "Retrieving running VMs in your labs ..."
$labs   = Get-AzLabAccount | Get-AzLab
$vms    = $labs | Get-AzLabVm -Status 'Running'

if($vms) {
    Write-Host "Building the username -> email lookup table ..."
    $users  = @{}
    $labs | Get-AzLabUser | ForEach-Object {$users[$_.name] = $_.properties.email}
    
    $email   = @{N = 'Email';  E = { $users.item($_.UserPrincipal)} }

    $vms `
        | Select-Object -Property ResourceGroupName, LabName, $email  `
        | Sort-Object   -Property ResourceGroupName, LabName, Email `
        | Out-Host

    Write-Host 'Whould you like to stop these Vms? (Default is No)'
    $Readhost = Read-Host " ( y / n ) "

    Switch($Readhost) {
        Y       { $vms | Stop-AzLabVm | Out-Null ; Write-Host 'Issued Stop command to VMs.' }
        N       { Write-Host 'Left VMs running.'}
        Default { Write-Host 'Left VMs running.' }
    }
} else {
    Write-Host "No running VMs in your labs."
}

Remove-Module Az.LabServices -Force