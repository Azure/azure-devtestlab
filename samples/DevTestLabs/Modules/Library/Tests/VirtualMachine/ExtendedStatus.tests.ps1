Import-Module $PSScriptRoot\..\..\Az.DevTestLabs2.psm1

$lab = @(
    [pscustomobject]@{Name=('DtlLibrary-Vm-' + (Get-Random)); ResourceGroupName=('DtlLibrary-VmRg-' + (Get-Random)); Location='eastus'}
)

$vm = @(
    [pscustomobject]@{VmName=('Vm-' + (Get-Random)); Size='Standard_A4_v2'; UserName='bob'; Password='aPassword341341'; OsType='Windows'; Sku='2012-R2-Datacenter'; Publisher='MicrosoftWindowsServer'; Offer='WindowsServer'}
)

Describe  'Virtual Machine Tests' {

    Context 'Properties' {

        It 'Extended status for Virtual Machine' {

            # Create the resource groups, using a little property projection
            $lab | Select-Object -Property @{N='Name'; E={$_.ResourceGroupName}}, Location | New-AzResourceGroup -Force | Out-Null

            # Create the lab
            $createdLab = $lab | New-AzDtlLab

            # Create VM in a lab
            $createdVM = $vm| Select-Object -Property @{N='Name'; E={$createdLab.Name}}, @{N='ResourceGroupName'; E={$createdLab.ResourceGroupName}}, VmName,Size,Claimable,Username,Password,OsType,Sku,Publisher,Offer | New-AzDtlVm

            # Stop the VM
            Stop-AzDtlVm -Vm $createdVM

            # Status fields of the VMs should be 'Stopped' for a VM stopped via DTL
            (Get-AzDtlVmStatus -Vm $createdVM -ExtendedStatus) | Should -Be "Stopped" -Because "$($createdVM.Name) should be stopped"

            # Start the VM
            Start-AzDtlVm -Vm $createdVM

            # Status field of the VMs should be'Running' for a VM started via DTL
            (Get-AzDtlVmStatus -Vm $createdVM -ExtendedStatus) | Should -Be "Running" -Because "$($createdVM.Name) should be running"
        }

        It 'Cleanup of resources' {

            # Remove Labs using the Lab Object returned from 'get' commandlet
            $lab | Get-AzDtlLab | Remove-AzDtlLab

            # Clean up the resource groups since we don't need them
            $lab | Select-Object -Property @{N='Name'; E={$_.ResourceGroupName}}, Location | Remove-AzResourceGroup -Force | Out-Null
        }
    }
}
