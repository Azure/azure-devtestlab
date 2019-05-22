[CmdletBinding()]
param()

function StringToFile([parameter(ValueFromPipeline=$true)][string] $text) {
  $tmp = New-TemporaryFile
  Set-Content -Path $tmp.FullName -Value $text
  return $tmp.FullName
}

Import-Module ..\Az.DevTestLabs.psm1

$users = @'
UserEmail, Role
lucabol@microsoft.com, "DevTest Labs User"
phauge@microsoft.com,  "DevTest Labs User"
'@

$lab = Dtl-NewLab -Name 'UserLab' -ResourceGroupName 'Cyber'

$users `
  | StringToFile `
  | Import-Csv `
  | Dtl-AddUser -Lab $lab

$lab | Dtl-RemoveLab

Remove-Module AzureRM.DevTestLab -Force
