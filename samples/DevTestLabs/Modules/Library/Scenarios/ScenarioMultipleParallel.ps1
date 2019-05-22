[CmdletBinding()]
param()

function StringToFile([parameter(ValueFromPipeline=$true)][string] $text) {
  $tmp = New-TemporaryFile
  Set-Content -Path $tmp.FullName -Value $text
  return $tmp.FullName
}

Import-Module ..\Az.DevTestLabs.psm1

$vms = @'
Name, ResourceGroupName, VmName, Size, UserName, Password, OsType, Sku, Publisher, Offer
MulLab1, Cyber, Vm1, Standard_A4_v2, bob, aPassword341341, Windows, 2012-R2-Datacenter, MicrosoftWindowsServer, WindowsServer
MulLab2, Cyber, Vm2, Standard_A4_v2, bob, aPassword341341, Windows, 2012-R2-Datacenter, MicrosoftWindowsServer, WindowsServer
'@

# Create labs
$lab = $vms `
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

$lab | dtl-getlab | dtl-RemoveLab

Remove-Module AzureRM.DevTestLab -Force
