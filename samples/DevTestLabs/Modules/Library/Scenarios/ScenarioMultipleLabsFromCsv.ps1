<#
This highlights how to use a single csv file to create multiple labs with multiple VMs
#>
[CmdletBinding()]
param()

function StringToFile([parameter(ValueFromPipeline=$true)][string] $text) {
  $tmp = New-TemporaryFile
  Set-Content -Path $tmp.FullName -Value $text
  return $tmp.FullName
}

Import-Module ..\Az.DevTestLabs2.psm1 -Force

$lab1 = "Test" + (Get-Random)
$lab2 = "Test" + (Get-Random)
$rgName = "TeRG" + (Get-Random)

New-AzureRmResourceGroup -Name $rgName -Location 'West Europe' | Out-Null

$vms = @"
Name, ResourceGroupName, VmName, Size, UserName, Password, OsType, Sku, Publisher, Offer
$lab1, $rgName, Vm1, Standard_A4_v2, bob, aPassword341341, Windows, 2012-R2-Datacenter, MicrosoftWindowsServer, WindowsServer
$lab2, $rgName, Vm2, Standard_A4_v2, bob, aPassword341341, Windows, 2012-R2-Datacenter, MicrosoftWindowsServer, WindowsServer
"@

# Create labs
$labs = $vms `
  | StringToFile `
  | Import-Csv `
  | Dtl-NewLab -AsJob `
  | Receive-Job -Wait

# Create vms
$vms `
  | StringToFile `
  | Import-Csv `
  | Dtl-NewVm -AsJob `
  | Receive-Job -Wait `
  | Dtl-StartVm `
  | Dtl-StopVm `
  | Dtl-RemoveVm

$labs | dtl-getlab | dtl-RemoveLab
Remove-AzureRmResourceGroup -Name $rgName -Force | Out-Null

Remove-Module Az.DevTestLabs2 -Force
