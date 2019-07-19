Import-Module $PSScriptRoot\..\..\Az.DevTestLabs2.psm1

$users = @'
UserEmail, Role
lucabol@microsoft.com, "DevTest Labs User"
phauge@microsoft.com,  "DevTest Labs User"
'@

$rgName = "DtlLibrary-LabUsersRg" + (Get-Random)
$labname = "DtlLibrary-LabUsers" + (Get-Random)

function StringToFile([parameter(ValueFromPipeline=$true)][string] $text) {
  $tmp = New-TemporaryFile
  Set-Content -Path $tmp.FullName -Value $text
  return $tmp.FullName
}

Describe  'DevTest Lab Users' {

    Context 'Pipeline Tests' {

      It 'Users can be added to a DevTest Lab successfully' {

        New-AzureRmResourceGroup -Name $rgName -Location 'West Europe' | Out-Null

        $lab = New-AzDtlLab -Name $labname -ResourceGroupName $rgName

        $users `
          | StringToFile `
          | Import-Csv `
          | Add-AzDtlLabUser -Lab $lab

      }

      It 'Clean up resources' {
        $lab = Get-AzDtlLab -Name $labname -ResourceGroupName $rgName

        $lab | Remove-AzDtlLab
        Remove-AzureRmResourceGroup -Name $rgName -Force | Out-Null

      }
    }
}
