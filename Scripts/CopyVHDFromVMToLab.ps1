[CmdletBinding()]
Param(
    # Enter the subscription ID. It is assumed that both source VM and destination lab are both in
    # this subscription.
    [Parameter(Mandatory)]
    [string]
    $SubscriptionId = '<SubscriptionId>',

    # Enter the name of the Lab where you want to copy the VHD file.
    [Parameter(Mandatory)]
    [string]
    $LabName = '<LabName>',
    
    # Enter the resource group name of the Lab where you want to copy the VHD file.
    [Parameter(Mandatory)]
    [string]
    $LabResourceGroupName = '<LabResourceGroupName>',
    
    # Enter the name of the VM. The VHD file associated with the VM will be copied to the Lab.
    [Parameter(Mandatory)]
    [string]
    $VMName = '<VMName>',

    # Enter the name of the VHD file with extension as .vhd. You will identify the file with this
    # name while creating template.
    [Parameter(Mandatory)]
    [string]
    $VHDFileName = '<VHDFileName>.vhd',
    
    # If you have created the VM from management portal or created the VM using Service Management
    # Stack from preview portal then enter specify the switch as -Classic; otherwise, do not specify
    # it and it will default to $false. If you have created the VM inside a Lab then please DO NOT
    # specify this switch on the command line.
    [Parameter(Mandatory = $false)]
    [switch]
    $Classic,

    # Enter the seconds after the Shared Access Signature on source will expired. Default value ist 3600.
    [Parameter(Mandatory = $false)]
    [int]
    $SignatureExpire = 3600
)

###################################################################################################
#
# PowerShell configurations
#

# NOTE: Because the $ErrorActionPreference is "Stop", this script will stop on first failure.
#       This is necessary to ensure we capture all errors inside the try-finally block.
$ErrorActionPreference = 'Stop'

# Ensure we set the working directory to that of the script.
pushd $PSScriptRoot

###################################################################################################
#
# Handle all errors in this script.
#

trap
{
    # NOTE: This trap will handle all errors. There should be no need to use a catch below in this
    #       script, unless you want to ignore a specific error.
    Handle-LastError
}

###################################################################################################
#
# Functions used in this script.
#

function Handle-LastError
{
    [CmdletBinding()]
    param(
    )

    $message = $error[0].Exception.Message
    if ($message)
    {
        Write-Host -Object "`nERROR: $message" -ForegroundColor Red
    }
    
    # IMPORTANT NOTE: Throwing a terminating error (using $ErrorActionPreference = "Stop") still
    # returns exit code zero from the PowerShell script when using -File. The workaround is to
    # NOT use -File when calling this script and leverage the try-finally block and return
    # a non-zero exit code from the trap.
    exit -1
}

function Get-AzureDtlLab
{
    [CmdletBinding()]
    param(
        [string]
        $Name,
        [string]
        $ResourceGroupName
    )

    return Get-AzureRmResource -ResourceName "$Name" -ResourceGroupName "$ResourceGroupName" -ResourceType 'Microsoft.DevTestLab/labs' -ExpandProperties
}

function Get-AzureDtlVirtualMachine
{
    [CmdletBinding()]
    param(
        [string]
        $Name,
        [switch]
        $Classic
    )

    $resourceType = 'Microsoft.Compute/virtualMachines'
    if ($Classic)
    {
        $resourceType = 'Microsoft.ClassicCompute/virtualMachines'
    }

    $vm = Find-AzureRmResource -ResourceType $resourceType -ResourceNameEquals "$Name" | Select -First 1
    if (-not $vm)
    {
        throw "Unable to find virtual machine with name '$Name'."
    }
    
    return $vm
}

function Get-AzureDtlVirtualMachineCopyContext
{
    [CmdletBinding()]
    param(
        $VM,
        [switch] $Classic,
        $SignatureExpire
    )

    $vmCopyContext = @{
        IsManaged = $false
        SourceUri = ''
        StorageAccountKey = ''
        StorageAccountName = ''
    }

    if ($Classic)
    {
        $disk = Get-AzureDisk | ? { $_.AttachedTo.RoleName -eq "$Name" }
        $vmCopyContext.SourceUri = $disk.MediaLink.AbsoluteUri
        $vmCopyContext.StorageAccountName = $disk.MediaLink.Host.Split('.')[0]
        $vmCopyContext.StorageAccountKey = (Get-AzureStorageKey -StorageAccountName $vmStorageAccountName).Primary
    }
    else
    {
        $properties = (Get-AzureRMResource -ResourceType $VM.ResourceType -ResourceName $VM.ResourceName -ResourceGroupName $VM.ResourceGroupName).Properties
        
        if ($properties.storageProfile.osDisk.managedDisk.id)
        {
            $managedDiskId = $properties.storageProfile.osDisk.managedDisk.id
            $managedDisk = Get-AzureRmResource -ResourceId $managedDiskId
            $managedDiskUrl = Grant-AzureRmDiskAccess -ResourceGroupName $managedDisk.ResourceGroupName -DiskName $managedDisk.Name -Access Read -DurationInSecond $SignatureExpire
            $vmCopyContext.SourceUri = $managedDiskUrl.AccessSAS
            $vmCopyContext.IsManaged = $true
        }
        elseif ($properties.storageProfile.osDisk.vhd.uri)
        {
            $vmCopyContext.SourceUri = $properties.storageProfile.osDisk.vhd.uri
            [System.Uri] $uri = $vmCopyContext.SourceUri
            $vmCopyContext.StorageAccountName = $uri.Host.Split('.')[0]
            $vmStorageAccount = Find-AzureRmResource -ResourceNameEquals $vmCopyContext.StorageAccountName -ResourceType 'Microsoft.Storage/storageAccounts'
            $vmCopyContext.StorageAccountKey = (Get-AzureRMStorageAccountKey -Name $vmCopyContext.StorageAccountName -ResourceGroupName $vmStorageAccount.ResourceGroupName)[0].Value
        }
    }
        
    return $vmCopyContext
}

function Stop-AzureDtlVirtualMachine
{
    [CmdletBinding()]
    param(
        $VM,
        [switch] $Classic
    )

    if ($Classic)
    {
        $classicVm = Get-AzureVM | ? { $_.Name -eq $VM.Name }
        Stop-AzureVM -Name $classicVm.Name -ServiceName $classicVm.ServiceName -Force | Out-Null
    }
    else
    {
        Stop-AzureRMVM -Name $VM.Name -ResourceGroupName $VM.ResourceGroupName -Force | Out-Null
    }
}

function Copy-AzureDtlVirtualMachineVhd
{
    [CmdletBinding()]
    param(
        $CopyContext
    )

    $destContext = New-AzureStorageContext -StorageAccountName $CopyContext.LabStorageAccountName -StorageAccountKey $CopyContext.LabStorageAccountKey

    if ($CopyContext.IsVMDiskManaged)
    {
        $copyHandle = Start-AzureStorageBlobCopy -AbsoluteUri $CopyContext.VMSourceUri -DestContainer 'uploads' -DestBlob $CopyContext.VHDFileName -DestContext $destContext
    }
    else
    {
        $srcContext = New-AzureStorageContext -StorageAccountName $CopyContext.VMStorageAccountName -StorageAccountKey $CopyContext.VMStorageAccountKey
        $copyHandle = Start-AzureStorageBlobCopy -AbsoluteUri $CopyContext.VMSourceUri -Context $srcContext -DestContainer 'uploads' -DestBlob $CopyContext.VHDFileName -DestContext $destContext
    }

    $copyStatus = $copyHandle | Get-AzureStorageBlobCopyState
    while ($copyStatus.Status -eq "Pending")
    {
        $copyStatus = $copyHandle | Get-AzureStorageBlobCopyState 
        $perComplete = ($copyStatus.BytesCopied / $copyStatus.TotalBytes) * 100
        Write-Progress -Activity "Copying blob ... " -Status "Percentage Complete" -PercentComplete "$perComplete"
        Start-Sleep 10
    }

    return $copyStatus
}

###################################################################################################
#
# Main execution block.
#

try
{
    $done = 'done.'

    Write-Host "Selecting subscription '$SubscriptionId' ... " -NoNewline
    Select-AzureSubscription -SubscriptionId $SubscriptionId -ErrorAction SilentlyContinue | Out-Null
    Select-AzureRMSubscription -SubscriptionId $SubscriptionId -ErrorAction SilentlyContinue | Out-Null
    Write-Host $done
    
    Write-Host "Getting lab '$LabName' under resource group '$LabResourceGroupName' ... " -NoNewline
    $lab = Get-AzureDtlLab -Name "$LabName" -ResourceGroupName "$LabResourceGroupName"
    Write-Host $done
    
    Write-Host 'Fetching lab storage account information ... ' -NoNewline
    $labStorageAccountName = $lab.Properties.DefaultStorageAccount.Split('/')[-1]
    $labStorageAccountKey = (Get-AzureRMStorageAccountKey -Name $labStorageAccountName -ResourceGroupName $LabResourceGroupName)[0].Value
    Write-Host $done

    Write-Host "Getting virtual machine '$VMName' ... " -NoNewline
    $vm = Get-AzureDtlVirtualMachine -Name "$VMName" -Classic:$Classic
    Write-Host $done

    Write-Host "Stopping source virtual machine '$VMName' ... " -NoNewline
    Stop-AzureDtlVirtualMachine -VM $vm -Classic:$Classic
    Write-Host $done

    Write-Host 'Preparing copy context ... ' -NoNewline
    $vmCopyContext = Get-AzureDtlVirtualMachineCopyContext -VM $vm -Classic:$Classic -SignatureExpire $SignatureExpire
    $copyContext = @{
        VHDFileName = $VHDFileName
        VMSourceUri = $vmCopyContext.SourceUri
        VMStorageAccountKey = $vmCopyContext.StorageAccountKey
        VMStorageAccountName = $vmCopyContext.StorageAccountName
        IsVMDiskManaged = $vmCopyContext.IsManaged
        LabStorageAccountKey = $labStorageAccountKey
        LabStorageAccountName = $labStorageAccountName
        SignatureExpire = $SignatureExpire
    }
    Write-Host $done

    Write-Host 'Dumping properties used for copy operation.'
    Write-Host "Lab ID = $($lab.ResourceId)"
    Write-Host "VM ID = $($vmCopyContext.Instance.ResourceId)"
    Write-Host "Copy Context: $(ConvertTo-Json $copyContext)"

    Write-Host "Copying VHD '$VHDFileName' to lab '$LabName' ... " -NoNewline
    $copyStatus = Copy-AzureDtlVirtualMachineVhd -CopyContext $copyContext
    if ($copyStatus.Status -ne 'Success')
    {
        throw "Unable to copy VHD '$vhdFileName' to lab '$labName'"
    }
    Write-Host $done
}
finally
{
    1..3 | % { [console]::beep(2500,300) } # Make a sound to indicate we're done.
    popd
}