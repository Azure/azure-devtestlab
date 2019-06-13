Import-Module $PSScriptRoot\..\..\Az.DevTestLabs2.psm1

$labs = @(
    [pscustomobject]@{Name='DTL-Library-Test1'; ResourceGroupName='DTL-Library-Test1rg'; Location='westus'},
    [pscustomobject]@{Name='DTL-Library-Test2'; ResourceGroupName='DTL-Library-Test2rg'; Location='eastus'}
)

$vms = @(
    [pscustomobject]@{VmName='BasicWinVm1'; Size='Standard_A4_v2'; UserName='bob'; Password='aPassword341341'; OsType='Windows'; Sku='2012-R2-Datacenter'; Publisher='MicrosoftWindowsServer'; Offer='WindowsServer'},
    [pscustomobject]@{VmName='BasicWinVm2'; Size='Standard_A4_v2'; UserName='bob'; Password='aPassword341341'; OsType='Windows'; Sku='2012-R2-Datacenter'; Publisher='MicrosoftWindowsServer'; Offer='WindowsServer'}
)

Describe  'Lab Creation and Deletion' {

    Context 'Pipeline Tests' {

        It 'DevTest Labs can be created with pipeline' {

            # Create the resource groups, using a little property projection
            $labs | Select-Object -Property @{N='Name'; E={$_.ResourceGroupName}}, Location | New-AzureRmResourceGroup -Force | Out-Null

            # Create the labs
            $createdLabs = $labs | New-AzDtlLab

            # Check the number of labs created
            $createdLabs.Count | Should be 2

            # Check that the labs really exist
            $createdLabs | Get-AzDtlLab | Should not be $null

        }

        It 'DevTest Labs can be deleted with pipeline' {

            # Remove Labs using the Lab Object returned from 'get' commandlet
            $labs | Get-AzDtlLab | Remove-AzDtlLab

            # Check that the labs are gone
            ($labs | Get-AzDtlLab -ErrorAction SilentlyContinue).Count | Should be 0
        }

        It 'Cleanup of resources' {

            # Clean up the resource groups since we don't need them
            $labs | Select-Object -Property @{N='Name'; E={$_.ResourceGroupName}}, Location | Remove-AzureRmResourceGroup -Force | Out-Null

        }
    }
}

Describe 'VM Management' {
    Context 'Pipeline Tests' {
        It 'DTL VMs can be created, started, and stopped with pipeline' {

            # Create the resource groups, using a little property projection
            $labs | Select-Object -Property @{N='Name'; E={$_.ResourceGroupName}}, Location | New-AzureRmResourceGroup -Force | Out-Null

            # Create the labs
            $createdLabs = $labs | New-AzDtlLab

            # Create VMs in a lab
            $createdVMs = $vms| Select-Object -Property @{N='Name'; E={$createdLabs[0].Name}}, @{N='ResourceGroupName'; E={$createdLabs[0].ResourceGroupName}}, VmName,Size,Claimable,Username,Password,OsType,Sku,Publisher,Offer | New-AzDtlVm

            $createdVMs.Count | Should be 2

            Get-AzDtlVM -Lab $createdLabs[0]  | Measure-Object | Select-Object -ExpandProperty Count | Should be 2

            Get-AzDtlVM -Lab $createdLabs[1]  | Measure-Object | Select-Object -ExpandProperty Count | Should be 0

            # Stop VMs
            $createdVMs | Stop-AzDtlVM | Measure-Object | Select-Object -ExpandProperty Count | Should be 2

            # Start VMs
            $createdVMs | Start-AzDtlVM | Measure-Object | Select-Object -ExpandProperty Count | Should be 2
        
        }

        It 'DTL VMs can be deleted with pipeline' {

            $createdLabs | Get-AzDtlVM | Remove-AzDtlVm

            $createdLabs | Get-AzDtlVM | Measure-Object | Select-Object -ExpandProperty Count | Should be 0
        }

        It 'Clean up of resources' {
            # Remove Labs using the Lab Object returned from 'get' commandlet
            $labs | Get-AzDtlLab | Remove-AzDtlLab

            # Check that the labs are gone
            ($labs | Get-AzDtlLab -ErrorAction SilentlyContinue).Count | Should be 0

            # Clean up the resource groups since we don't need them
            $labs | Select-Object -Property @{N='Name'; E={$_.ResourceGroupName}}, Location | Remove-AzureRmResourceGroup -Force | Out-Null


        }
    }
}
