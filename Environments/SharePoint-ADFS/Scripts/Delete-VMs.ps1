param(
    [string[]] $VMsToDelete = @("SP", "SQL", "DC"),
    [string] $ResourceGroupLocation = "westeurope"
)

<#
$ResourceGroupLocation = 'westeurope'
$resourceGroupName = 'ydsp16adfs'
$resourceGroupName = 'xydsp16adfs'
$VMsToDelete = @("SP", "SQL", "DC")
$VMsToDelete = @("SP", "FE")
#$VMsToDelete = @("SP")
#>

Import-Module Azure -ErrorAction SilentlyContinue
$azurecontext = Get-AzureRmContext -ErrorAction SilentlyContinue
if ($azurecontext -eq $null -or $azurecontext.Account -eq $null -or $azurecontext.Subscription -eq $null){ 
    Write-Host "Launching Azure authentication prompt..." -ForegroundColor Green
    Login-AzureRmAccount
    $azurecontext = Get-AzureRmContext -ErrorAction SilentlyContinue
}
if ($azurecontext -eq $null -or $azurecontext.Account -eq $null -or $azurecontext.Subscription -eq $null){ 
    Write-Host "Unable to get a valid context." -ForegroundColor Red
    return
}

Get-AzureRmContext

<#
.SYNOPSIS
Delete VMs specified and their virtual disks

.DESCRIPTION
De

.PARAMETER vmsToDelete
VMs to delete

.EXAMPLE
An example

.NOTES
General notes
#>
function Delete-VMs($VMsToDelete) {
    ForEach ($vmToDelete in $VMsToDelete) {
    #$VMsToDelete| Foreach-Object -Process {
        #$vmToDelete = $_
        $disksNames = @()
        $vm = Get-AzureRmVM -ResourceGroupName $resourceGroupName -Name $vmToDelete
        $disksNames += $vm.StorageProfile.OsDisk.Name
        $vm.StorageProfile.DataDisks| %{$disksNames += $_.Name}
        
        Write-Host "Removing VM $vmToDelete..." -ForegroundColor Magenta
        Remove-AzureRmVM -ResourceGroupName $resourceGroupName -Name $vmToDelete -Force

        $disksNames| Foreach-Object -Process {
            Write-Host "Removing disk $_..." -ForegroundColor Magenta
            Remove-AzureRmDisk -ResourceGroupName $resourceGroupName -DiskName "$_" -Force;
        }
        Write-Host "VM $vmToDelete deleted." -ForegroundColor Magenta
    }
}

Delete-VMs $VMsToDelete
Write-Host "Finished." -ForegroundColor Magenta
