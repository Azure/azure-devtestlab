[CmdletBinding()]
param()

function StringToFile([parameter(ValueFromPipeline=$true)][string] $text) {
  $tmp = New-TemporaryFile
  Set-Content -Path $tmp.FullName -Value $text
  return $tmp.FullName
}

Import-Module ..\Az.DevTestLabs2.psm1 -Force

$users = @'
UserEmail, Role
lucabol@microsoft.com, "DevTest Labs User"
phauge@microsoft.com,  "DevTest Labs User"
'@

$labname = "Test" + (Get-Random)

$lab = Dtl-NewLab -Name $labname -ResourceGroupName 'TestLibrary'

$users `
  | StringToFile `
  | Import-Csv `
  | Dtl-AddUser -Lab $lab

$lab | Dtl-RemoveLab

Remove-Module Az.DevTestLabs2 -Force
