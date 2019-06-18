<#
This highlights how to use a single csv file to create multiple labs with multiple VMs
#>

Import-Module $PSScriptRoot\..\..\Az.DevTestLabs2.psm1

function StringToFile([parameter(ValueFromPipeline=$true)][string] $text) {
  $tmp = New-TemporaryFile
  Set-Content -Path $tmp.FullName -Value $text
  return $tmp.FullName
}

$lab1 = "DtlLibraryTest" + (Get-Random)
$lab2 = "DtlLibraryTest" + (Get-Random)
$rgName = "DtlLibraryTestRG" + (Get-Random)

$vms = @"
Name, ResourceGroupName, VmName, Size, UserName, Password, OsType, Sku, Publisher, Offer
$lab1, $rgName, Vm1, Standard_A4_v2, bob, aPassword341341, Windows, 2012-R2-Datacenter, MicrosoftWindowsServer, WindowsServer
$lab2, $rgName, Vm2, Standard_A4_v2, bob, aPassword341341, Windows, 2012-R2-Datacenter, MicrosoftWindowsServer, WindowsServer
"@

Describe  'Scenario Tests' {

    Context 'Multiple Labs' {

      It 'DevTest Labs can be created with VMs' {
        New-AzureRmResourceGroup -Name $rgName -Location 'West Europe' | Out-Null

        # Create labs
        $vms `
          | StringToFile `
          | Import-Csv `
          | New-AzDtlLab -AsJob `
          | Receive-Job -Wait `
          | Out-Null
        
        # Create vms
        $vms `
          | StringToFile `
          | Import-Csv `
          | New-AzDtlVm -AsJob `
          | Receive-Job -Wait `
          | Start-AzDtlVm `
          | Stop-AzDtlVm `
          | Remove-AzDtlVm
      }

      It 'Clean up resources' {

        $labs = $vms `
        | StringToFile `
        | Import-Csv `
        | Get-AzDtlLab

        $labs | Remove-AzDtlLab

        Remove-AzureRmResourceGroup -Name $rgName -Force | Out-Null
        
      }
    }
}
