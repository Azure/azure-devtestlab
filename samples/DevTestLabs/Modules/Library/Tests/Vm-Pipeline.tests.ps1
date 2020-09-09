[cmdletbinding()]
Param()

Import-Module $PSScriptRoot\..\Az.DevTestLabs2.psm1 -Verbose:$false

$labs = @(
    [pscustomobject]@{Name=('DtlLibrary-VmPipeline-' + (Get-Random)); ResourceGroupName=('DtlLibrary-VmPipelineRg-' + (Get-Random)); Location='westus'},
    [pscustomobject]@{Name=('DtlLibrary-VmPipeline-' + (Get-Random)); ResourceGroupName=('DtlLibrary-VmPipelineRg-' + (Get-Random)); Location='eastus'}
)

$vms = @(
    [pscustomobject]@{VmName=('Vm-' + (Get-Random)); Size='Standard_B4ms'; UserName='bob'; Password='aPassword341341'; OsType='Windows'; Sku='2012-R2-Datacenter'; Publisher='MicrosoftWindowsServer'; Offer='WindowsServer'}
    [pscustomobject]@{VmName=('Vm-' + (Get-Random)); Size='Standard_B4ms'; UserName='bob'; Password='aPassword341341'; OsType='Windows'; Sku='2012-R2-Datacenter'; Publisher='MicrosoftWindowsServer'; Offer='WindowsServer'}
)

Describe 'VM Management' {
    Context 'Pipeline Tests' {
        It 'DTL VMs can be created, started, and stopped with pipeline' {

            # Create the resource groups, using a little property projection
            $labs | Select-Object -Property @{N='Name'; E={$_.ResourceGroupName}}, Location | New-AzureRmResourceGroup -Force | Out-Null

            # Create the labs
            $createdLabs = $labs | New-AzDtlLab

            # WORKAROUND for 1082372
            $labs | ForEach-Object {
                Set-AzResource -ResourceGroupName $_.ResourceGroupName -ResourceType 'Microsoft.DevTestLab/labs/users' -Name "$($_.Name)/@me" -ApiVersion 2018-10-15-preview -Force
            }
            
            # Query Azure to get the created labs to make sure they really exist
            $createdLabs = $labs | Get-AzDtlLab
            $createdLabs.Count | Should -Be 2

            # Create VMs in a lab
            $createdVMs = $vms| Select-Object -Property @{N='Name'; E={$createdLabs[0].Name}}, @{N='ResourceGroupName'; E={$createdLabs[0].ResourceGroupName}}, VmName,Size,Claimable,Username,Password,OsType,Sku,Publisher,Offer | New-AzDtlVm
            $createdVMs = Get-AzDtlVm -Lab $createdLabs[0]

            Write-Verbose "Created VMs:"
            $createdVMs | Out-String | Write-Verbose
 
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

            $vms = $labs | Get-AzDtlVM
            Write-Verbose "VMs before delete"
            $vms | Out-String | Write-Verbose

            $vms | Remove-AzDtlVm

            # If we query DTL too fast before they update records, the VM will still show up
            # need to wait for DTL to catch up - only happens occasionally
            Start-Sleep -Seconds 60

            $vms = $labs | Get-AzDtlVm
            Write-Verbose "VMs after delete"
            $vms | Out-String | Write-Verbose
            $vms | Measure-Object | Select-Object -ExpandProperty Count | Should -Be 0
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