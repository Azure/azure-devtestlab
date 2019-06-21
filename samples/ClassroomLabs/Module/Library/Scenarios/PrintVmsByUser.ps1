<#
Prints out a report of all VMs.
#>
[CmdletBinding()]
param()

Import-Module ..\Az.AzureLabs.psm1 -Force

Write-Host "Retrieving VMs in your labs ..."
$labs   = Get-AzLabAccount | Get-AzLab
$vms    = $labs | Get-AzLabVm

if($vms) {
    Write-Host "Building the username -> email lookup table ..."
    $users  = @{}
    $labs | Get-AzLabUser | ForEach-Object {$users[$_.name] = $_.properties.email}
    
    $email   = @{N = 'Email';  E = { $users.item($_.UserPrincipal)} }

    $vms `
        | Select-Object -Property $email, ResourceGroupName, LabName, Status `
        | Sort-Object   -Property Email, ResourceGroupName, LabName, Status -Descending `
        | Format-Table  -GroupBy Email -Property ResourceGroupName, LabName, Status `
        | Out-Host

} else {
    Write-Host "No VMs in your labs."
}

Remove-Module Az.AzureLabs -Force