param(
    [string] $VMName = "Client",
    [Parameter(Mandatory=$true)] [string] $ResourceGroupName,
    [string] $ResourceGroupLocation = "westeurope",
    [Parameter(Mandatory=$true)] [string] $StorageAccountName
)

<#
.\New-VM.ps1 -VMName "Client" -ResourceGroupName "yd-sp16adfs" -ResourceGroupLocation "westeurope" -StorageAccountName "ydsp16adfsst"
#>

Import-Module Azure -ErrorAction SilentlyContinue
$azurecontext = Get-AzureRmContext -ErrorAction SilentlyContinue
if ($azurecontext -eq $null -or $azurecontext.Account -eq $null -or $azurecontext.Subscription -eq $null) {
    Write-Host "Launching Azure authentication prompt..." -ForegroundColor Green
    Login-AzureRmAccount
    $azurecontext = Get-AzureRmContext -ErrorAction SilentlyContinue
}
if ($azurecontext -eq $null -or $azurecontext.Account -eq $null -or $azurecontext.Subscription -eq $null){ 
    Write-Host "Unable to get a valid context." -ForegroundColor Red
    return
}

function New-VM($VMName) {
    ## Network
    $publicIpName = "vm$VMName-PublicIP"
    $nicName = "vm$VMName-nic-0"
    $VNetName = "$ResourceGroupName-vnet"
    $VNetName = "ydsp16adfs-vnet"
    #$VNetAddressPrefix = "10.0.0.0/16"
    #$VNetSubnetAddressPrefix = "10.0.3.0/24"
    $Subnet1Name = "Subnet-3"
    $dnsServer = "10.0.1.4"
    
    ## Compute
    $VMName = "$VMName"
    $ComputerName = "$VMName"
    $VMSize = "Basic_A2"
    $OSDiskName = "vm-$VMName-OSDisk"

    # Storage
    $StorageAccount = Get-AzureRmStorageAccount -ResourceGroupName $ResourceGroupName -Name $StorageAccountName

    # Network
    $VNet = Get-AzureRmVirtualNetwork -Name $VNetName -ResourceGroupName $ResourceGroupName
    $SubnetConfig = Get-AzureRmVirtualNetworkSubnetConfig -Name $Subnet1Name -VirtualNetwork $VNet
    $PIp = Get-AzureRmPublicIpAddress -Name $publicIpName -ResourceGroupName $ResourceGroupName -ErrorAction SilentlyContinue
    if ($PIp -eq $null) { $PIp = New-AzureRmPublicIpAddress -Name $publicIpName -ResourceGroupName $ResourceGroupName -Location $ResourceGroupLocation -AllocationMethod Dynamic }
    $Interface = Get-AzureRmNetworkInterface -Name $nicName -ResourceGroupName $ResourceGroupName -ErrorAction SilentlyContinue
    if ($Interface -eq $null) { $Interface = New-AzureRmNetworkInterface -Name $nicName -ResourceGroupName $ResourceGroupName -Location $ResourceGroupLocation -SubnetId $SubnetConfig.Id -PublicIpAddressId $PIp.Id -DnsServer $dnsServer }
    
    # Compute
    ## Setup local VM object
    $Credential = Get-Credential
    $VirtualMachine = New-AzureRmVMConfig -VMName $VMName -VMSize $VMSize
    $VirtualMachine = Set-AzureRmVMOperatingSystem -VM $VirtualMachine -Windows -ComputerName $ComputerName -Credential $Credential -ProvisionVMAgent -EnableAutoUpdate
    $VirtualMachine = Set-AzureRmVMSourceImage -VM $VirtualMachine -PublisherName MicrosoftWindowsServer -Offer WindowsServer -Skus 2016-Datacenter -Version "latest"
    $VirtualMachine = Add-AzureRmVMNetworkInterface -VM $VirtualMachine -Id $Interface.Id
    $OSDiskUri = $StorageAccount.PrimaryEndpoints.Blob.ToString() + "vhds/" + $OSDiskName + ".vhd"
    $VirtualMachine = Set-AzureRmVMOSDisk -VM $VirtualMachine -Name $OSDiskName -VhdUri $OSDiskUri -CreateOption FromImage

    ## Create the VM in Azure
    New-AzureRmVM -ResourceGroupName $ResourceGroupName -Location $ResourceGroupLocation -VM $VirtualMachine
}

New-VM $VMName
Write-Output "Finished."
