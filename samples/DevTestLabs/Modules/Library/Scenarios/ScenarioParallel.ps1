[CmdletBinding()]
param()

function StringToFile([parameter(ValueFromPipeline=$true)][string] $text) {
  $tmp = New-TemporaryFile
  Set-Content -Path $tmp.FullName -Value $text
  return $tmp.FullName
}

Import-Module ..\Az.DevTestLabs.psm1

$vms = @'
VmName, Size, UserName, Password, OsType, Sku, Publisher, Offer
Vm1, Standard_A4_v2, bob, aPassword341341, Windows, 2012-R2-Datacenter, MicrosoftWindowsServer, WindowsServer
Vm2, Standard_A4_v2, bob, aPassword341341, Windows, 2012-R2-Datacenter, MicrosoftWindowsServer, WindowsServer
'@

$lab = Dtl-NewLab -Name 'ParaLab' -ResourceGroupName 'Cyber' -AsJob | Receive-Job -Wait

$vms `
  | StringToFile `
  | Import-Csv `
  | Dtl-NewVm -Lab $lab -AsJob `
  | Receive-Job -Wait `
  | Dtl-StartVm `
  | Dtl-StopVm `
  | Dtl-RemoveVm

$lab | dtl-getlab | dtl-RemoveLab

Remove-Module AzureRM.DevTestLab -Force
