[cmdletbinding()]
Param()

Import-Module $PSScriptRoot\..\Az.DevTestLabs2.psm1 -Verbose:$false

$lab = @(
    [pscustomobject]@{Name=('DtlLibrary-VmProperties-' + (Get-Random)); ResourceGroupName=('DtlLibrary-VmProperties-rg-' + (Get-Random)); Location='westus'}
)

$vm = @(
    [pscustomobject]@{VmName=('Vm-' + (Get-Random)); Size='Standard_B4ms'; UserName='bob'; Password='aPassword341341'; OsType='Windows'; Sku='2012-R2-Datacenter'; Publisher='MicrosoftWindowsServer'; Offer='WindowsServer'}
)

Describe 'Virtual Machine Management' {

    Context 'Virtual Machine Properties' {

        It 'Create initial resources' {
            # Create the resource groups, using a little property projection
            $lab | Select-Object -Property @{N='Name'; E={$_.ResourceGroupName}}, Location | New-AzureRmResourceGroup -Force | Out-Null

            # Create the lab
            $createdLab = $lab | New-AzDtlLab

            # WORKAROUND for 1082372
            $lab | ForEach-Object {
                Set-AzResource -ResourceGroupName $_.ResourceGroupName -ResourceType 'Microsoft.DevTestLab/labs/users' -Name "$($_.Name)/@me" -ApiVersion 2018-10-15-preview -Force
            }
            
            Write-Verbose "Original Lab Object:"
            $lab | Out-String | Write-Verbose

            Write-Verbose "Created Lab:"
            $createdLab | Out-String | Write-Verbose

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