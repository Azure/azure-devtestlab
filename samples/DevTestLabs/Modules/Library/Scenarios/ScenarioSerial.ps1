[CmdletBinding()]
param()

function StringToFile([parameter(ValueFromPipeline=$true)][string] $text) {
  $tmp = New-TemporaryFile
  Set-Content -Path $tmp.FullName -Value $text
  return $tmp.FullName
}

Import-Module ..\Az.DevTestLabs2.psm1

$labs = @'
Name, ResourceGroupName
LibLab1, TestLibrary
LibLab2, TestLibrary
'@

$labs `
  | StringToFile `
  | Import-Csv `
  | Dtl-NewLab `
  | Dtl-AddUser -UserEmail 'lucabol@microsoft.com' `
  | Dtl-SetLabAnnouncement -Title 'I am here' -AnnouncementMarkDown 'yep' `
  | Dtl-SetLabSupport -SupportMarkdown "### Support me, baby!" `
  | Dtl-NewVm -VmName "WinServer" -Size 'Standard_A4_v2' -Claimable -UserName 'bob' -Password 'aPassword341341' `
              -OsType Windows -Sku '2012-R2-Datacenter' -Publisher 'MicrosoftWindowsServer' -Offer 'WindowsServer' `
  | Dtl-StartVm `
  | Dtl-ClaimVm `
  | Dtl-StopVm `
  | Dtl-RemoveVm

  $labs `
  | StringToFile `
  | Import-Csv `
  | Dtl-GetLab `
  | Dtl-RemoveLab

  Remove-Module Az.DevTestLabs2 -Force
