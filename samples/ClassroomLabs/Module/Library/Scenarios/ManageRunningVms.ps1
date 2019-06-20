<#
Prints out a report of all running VMs and asks confirmation to stop them.
NOTE: this could be made faster by changing the implementation of Get-AzLabVmUser
      or avoiding calling it.
#>
[CmdletBinding()]
param()

Import-Module ..\Az.AzureLabs.psm1 -Force

Write-Host "Retrieving running VMs in your labs ..."
$vms = Get-AzLabAccount | Get-AzLab | Get-AzLabVm -Status 'Running'

if($vms) {
    $lab    = @{N = 'Lab'  ; E = {$_.id.Split('/')[10]}}
    $user   = @{N = 'User';  E = {($_ | Get-AzLabVmUser).properties.email}}
    $vms `
        | Select-Object -Property $lab, $user  `
        | Sort-Object -Property Lab, User `
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

Remove-Module Az.AzureLabs -Force