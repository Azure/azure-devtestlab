[CmdletBinding()]
param()

Import-Module ..\Az.AzureLabs.psm1 -Force

Get-AzLabAccount | Get-AzLab | Get-AzLabVm -Status 'Running'

Remove-Module Az.AzureLabs -Force