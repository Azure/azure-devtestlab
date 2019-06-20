Import-Module $PSScriptRoot\..\..\Az.DevTestLabs2.psm1

$labs = @(
    [pscustomobject]@{Name=('DtlLibrary-Vm-' + (Get-Random)); ResourceGroupName=('DtlLibrary-VmRg-' + (Get-Random)); Location='westus'},
    [pscustomobject]@{Name=('DtlLibrary-Vm-' + (Get-Random)); ResourceGroupName=('DtlLibrary-VmRg-' + (Get-Random)); Location='eastus'}
)

$vms = @(
    [pscustomobject]@{VmName=('Vm-' + (Get-Random)); Size='Standard_A4_v2'; UserName='bob'; Password='aPassword341341'; OsType='Windows'; Sku='2012-R2-Datacenter'; Publisher='MicrosoftWindowsServer'; Offer='WindowsServer'}
    [pscustomobject]@{VmName=('Vm-' + (Get-Random)); Size='Standard_A4_v2'; UserName='bob'; Password='aPassword341341'; OsType='Windows'; Sku='2012-R2-Datacenter'; Publisher='MicrosoftWindowsServer'; Offer='WindowsServer'}
)

Describe 'VM Management' {
    Context 'Pipeline Tests' {
        It 'DTL VMs can be created, started, and stopped with pipeline' {

            # Create the resource groups, using a little property projection
            $labs | Select-Object -Property @{N='Name'; E={$_.ResourceGroupName}}, Location | New-AzureRmResourceGroup -Force | Out-Null

            # Create the labs
            $createdLabs = $labs | New-AzDtlLab

            # Create VMs in a lab
            $createdVMs = $vms| Select-Object -Property @{N='Name'; E={$createdLabs[0].Name}}, @{N='ResourceGroupName'; E={$createdLabs[0].ResourceGroupName}}, VmName,Size,Claimable,Username,Password,OsType,Sku,Publisher,Offer | New-AzDtlVm

            $createdVMs.Count | Should -Be 2

            Get-AzDtlVM -Lab $createdLabs[0]  | Measure-Object | Select-Object -ExpandProperty Count | Should -Be 2

            Get-AzDtlVM -Lab $createdLabs[1]  | Measure-Object | Select-Object -ExpandProperty Count | Should -Be 0

            # Stop VMs
            $createdVMs | Stop-AzDtlVM
            # confirm they are stopped
            $createdVMs | Get-AzDtlVmStatus -ExtendedStatus | Where-Object {$_ -eq "Stopped"} | Measure-Object | Select-Object -ExpandProperty Count | Should -Be 2

            # Start VMs
            $createdVMs | Start-AzDtlVM
            # confirm they are started
            $createdVMs | Get-AzDtlVmStatus -ExtendedStatus | Where-Object {$_ -eq "Running"}| Measure-Object | Select-Object -ExpandProperty Count | Should -Be 2
        
        }

        It 'DTL VMs can be deleted with pipeline' {

            $labs | Get-AzDtlVM | Remove-AzDtlVm

            $labs | Get-AzDtlVM | Measure-Object | Select-Object -ExpandProperty Count | Should -Be 0
        }

        It 'Clean up of resources' {
            # Remove Labs using the Lab Object returned from 'get' commandlet
            $labs | Get-AzDtlLab | Remove-AzDtlLab

            # Check that the labs are gone
            ($labs | Get-AzDtlLab -ErrorAction SilentlyContinue).Count | Should -Be 0

            # Clean up the resource groups since we don't need them
            $labs | Select-Object -Property @{N='Name'; E={$_.ResourceGroupName}}, Location | Remove-AzureRmResourceGroup -Force | Out-Null


        }
    }
}