Import-Module $PSScriptRoot\..\..\Az.DevTestLabs2.psm1

$lab = @(
    [pscustomobject]@{Name=('DtlLibrary-Vm-' + (Get-Random)); ResourceGroupName=('DtlLibrary-VmRg-' + (Get-Random)); Location='westus'}
)

$vm = @(
    [pscustomobject]@{VmName=('Vm-' + (Get-Random)); Size='Standard_A4_v2'; UserName='bob'; Password='aPassword341341'; OsType='Windows'; Sku='2012-R2-Datacenter'; Publisher='MicrosoftWindowsServer'; Offer='WindowsServer'}
)

Describe 'Virtual Machine Management' {

    Context 'Virtual Machine Properties' {

        It 'Create initial resources' {
            # Create the resource groups, using a little property projection
            $lab | Select-Object -Property @{N='Name'; E={$_.ResourceGroupName}}, Location | New-AzureRmResourceGroup -Force | Out-Null

            # Create the lab
            $createdLab = $lab | New-AzDtlLab

            # Create a VM in the lab
            $vm | Select-Object -Property @{N='Name'; E={$createdLab.Name}}, @{N='ResourceGroupName'; E={$createdLab.ResourceGroupName}}, VmName,Size,Claimable,Username,Password,OsType,Sku,Publisher,Offer | New-AzDtlVm

            # Confirm the VM was created
            $lab | Dtl-GetVm | Should -Not -Be $null
        }

        It 'Can get the RDP file associated with a VM' {
            
            # Get the VM from the Lab
            $createdVm = $lab | Dtl-GetVm

            # Get the RDP file for the VM
            $createdVM | Get-AzDtlVmRdpFileContents | Should -Not -Be $null
        }

        It 'Clean up of resources' {

            # Remove the VM
            $lab | Get-AzDtlVM | Remove-AzDtlVm

            # Remove Lab using the Lab Object returned from 'get' commandlet
            $lab | Get-AzDtlLab | Remove-AzDtlLab

            # Clean up the resource groups since we don't need them
            $lab | Select-Object -Property @{N='Name'; E={$_.ResourceGroupName}}, Location | Remove-AzureRmResourceGroup -Force | Out-Null

        }
    }
}