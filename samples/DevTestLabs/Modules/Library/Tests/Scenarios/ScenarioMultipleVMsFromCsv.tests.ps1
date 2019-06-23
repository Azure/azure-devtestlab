<#
This highlights how to use a single csv file to create multiple VMs in a single lab
#>

Import-Module $PSScriptRoot\..\..\Az.DevTestLabs2.psm1

$rgName = "DtlLibraryTestRG" + (Get-Random)
$labname = "DtlLibraryTest" + (Get-Random)

$vms = @'
VmName, Size, UserName, Password, OsType, Sku, Publisher, Offer
Vm1, Standard_A4_v2, bob, aPassword341341, Windows, 2012-R2-Datacenter, MicrosoftWindowsServer, WindowsServer
Vm2, Standard_A4_v2, bob, aPassword341341, Windows, 2012-R2-Datacenter, MicrosoftWindowsServer, WindowsServer
'@

function StringToFile([parameter(ValueFromPipeline=$true)][string] $text) {
  $tmp = New-TemporaryFile
  Set-Content -Path $tmp.FullName -Value $text
  return $tmp.FullName
}

Describe  'Scenario Tests' {

    Context 'Multiple VMs' {

      It 'Multiple Virtual Machines can be created in a lab' {
        New-AzureRmResourceGroup -Name $rgName -Location 'West Europe' | Out-Null
        $lab = New-AzDtlLab -Name $labname -ResourceGroupName $rgName -AsJob | Receive-Job -Wait

        $vms `
        | StringToFile `
        | Import-Csv `
        | New-AzDtlVm -Lab $lab -AsJob `
        | Receive-Job -Wait `
        | Start-AzDtlVm `
        | Stop-AzDtlVm

        $lab | Get-AzDtlVm | Remove-AzDtlVm
      
        ($lab | Get-AzDtlVm).Count | Should -Be 0
      }

      It 'Clean up resources' {

        Get-AzDtlLab -Name $labname -ResourceGroupName $rgName | Remove-AzDtlLab
        Remove-AzureRmResourceGroup -Name $rgName -Force | Out-Null
        
      }
    }
}
