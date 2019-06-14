<#
This highlights how to use a single csv file to create multiple VMs in a single lab
#>
[CmdletBinding()]
param()

function StringToFile([parameter(ValueFromPipeline=$true)][string] $text) {
  $tmp = New-TemporaryFile
  Set-Content -Path $tmp.FullName -Value $text
  return $tmp.FullName
}

Import-Module ..\Az.DevTestLabs2.psm1 -Force

$rgName = "TeRG" + (Get-Random)

New-AzureRmResourceGroup -Name $rgName -Location 'West Europe' | Out-Null

$vms = @'
VmName, Size, UserName, Password, OsType, Sku, Publisher, Offer
Vm1, Standard_A4_v2, bob, aPassword341341, Windows, 2012-R2-Datacenter, MicrosoftWindowsServer, WindowsServer
Vm2, Standard_A4_v2, bob, aPassword341341, Windows, 2012-R2-Datacenter, MicrosoftWindowsServer, WindowsServer
'@

$labname = "Test" + (Get-Random)

$lab = New-AzDtlLab -Name $labname -ResourceGroupName $rgName -AsJob | Receive-Job -Wait

$vms `
  | StringToFile `
  | Import-Csv `
  | New-AzDtlVm -Lab $lab -AsJob `
  | Receive-Job -Wait `
  | Start-AzDtlVm `
  | Stop-AzDtlVm `
  | Remove-AzDtlVm

$lab | Get-AzDtlLab | Remove-AzDtlLab
Remove-AzureRmResourceGroup -Name $rgName -Force | Out-Null

Remove-Module Az.DevTestLabs2 -Force
