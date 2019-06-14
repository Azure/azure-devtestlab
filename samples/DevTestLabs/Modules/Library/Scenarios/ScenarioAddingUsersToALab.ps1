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

$users = @'
UserEmail, Role
lucabol@microsoft.com, "DevTest Labs User"
phauge@microsoft.com,  "DevTest Labs User"
'@

$labname = "Test" + (Get-Random)

$lab = Get-AzDtlLab -Name $labname -ResourceGroupName $rgName

$users `
  | StringToFile `
  | Import-Csv `
  | Add-AzDtlLabUser -Lab $lab

$lab | Remove-AzDtlLab
Remove-AzureRmResourceGroup -Name $rgName -Force | Out-Null

Remove-Module Az.DevTestLabs2 -Force
