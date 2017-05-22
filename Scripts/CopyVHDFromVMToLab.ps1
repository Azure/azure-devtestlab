
#Please enter the name of the VM. The VHD file associated with the VM will be copied to Lab
$vmName = 'TestVM'

#Please enter the name of the Lab where you want to copy the VHD file.
$labName = 'ContosoLab86'

#Please enter the name of the VHD file with extension as .vhd. You will identify the file with this name while creating template.
$vhdFileName = 'TestVM.vhd'

#If you have created the VM from management portal or created the VM using Service Management Stack from preview portal then enter $true otherwise enter $false.
#If you have created the VM inside a Lab then please set the variable as $false
$isVMClassic = $false

#Enter the Subscription Id
$subscriptionId = '00c7b539-06b3-4dbc-8b04-2963d83c5c79'

#If you dont want to enter credential again and again, please set this variable to false
$skipCredential = $true

####### Main ###############################################################

If($skipCredential -eq $false){

    $accounts = Get-AzureAccount 

    foreach($acc in $accounts){

      Remove-AzureAccount -Name $acc.Id -Force -WarningAction SilentlyContinue
    }

    Add-AzureAccount | Out-Null
}

Select-AzureSubscription -SubscriptionId $subscriptionId -WarningAction SilentlyContinue
Select-AzureRMSubscription -SubscriptionId $subscriptionId -WarningAction SilentlyContinue

#Switch-AzureMode -Name AzureResourceManager -WarningAction SilentlyContinue

Write-Host 'Searching for the Lab..'



$labs = Find-AzureRmResource -ResourceType 'Microsoft.DevTestLab/labs' 

$isLabPresent = $false

foreach($lab in $labs){


    if($lab.ResourceName -eq $labName){

        $isLabPresent = $true
        
        Write-Host 'Lab search successful.' 

        $properties = (Get-AzureRMResource  -ResourceType 'Microsoft.DevTestLab/labs' -ResourceName $lab.ResourceName -ResourceGroupName $lab.ResourceGroupName -WarningAction SilentlyContinue).Properties




        Write-Host 'Fetching the storage account and storage account key for the Lab..'

        $labStorageAccountId = $properties.DefaultStorageAccount.Split('/')
        
        $labStorageAccountName =  $labStorageAccountId[$labStorageAccountId.Length-1]

        $labStorageAccountKey = (Get-AzureRMStorageAccountKey -Name $labStorageAccountName -ResourceGroupName $lab.ResourceGroupName)[0].Value 

        Write-Host 'Successfully fetched the storage account and storage account key for the Lab..'

    }

}

if($isLabPresent -eq $false){

     THROW 'Lab $labName does not exist in the subscription provided'
}

$resourceType = 'Microsoft.Compute/virtualMachines'

if($isVMClassic -eq $true){

    $resourceType = 'Microsoft.ClassicCompute/virtualMachines'
}
$vms = Find-AzureRmResource -ResourceType $resourceType

Write-Host 'Searching VM in the subscription..'


foreach($vm in $vms){


    if($vm.ResourceName -eq $vmName){
         
        
        Write-Host 'VM Search successful.'
        
        if($isVMClassic -eq $true){
             
                #Switch-AzureMode -Name AzureServiceManagement -WarningAction SilentlyContinue
                
                $disk = Get-AzureDisk | Where-Object { $_.AttachedTo.RoleName -eq "$vmName" }

                $sourceUri = $disk.MediaLink.AbsoluteUri

                $vmStorageAccountName = $disk.MediaLink.Host.Split('.')[0]

                $vmStorageAccountKey = (Get-AzureStorageKey -StorageAccountName $vmStorageAccountName).Primary

                $classicVm = Get-AzureVM | Where-Object{$_.Name -eq $vmName}

                Write-Host 'Successfully fetched the storage account and storage account key for the VM.'

                Write-Host 'Stopping VM..'

                Stop-AzureVM -Name $classicVm.Name -ServiceName $classicVm.ServiceName -Force | Out-Null

                Write-Host 'Successfully stopped VM'

                #Switch-AzureMode -Name AzureResourceManager
              
              

        }else{
            
            $properties = (Get-AzureRMResource  -ResourceType $resourceType -ResourceName $vm.ResourceName -ResourceGroupName $vm.ResourceGroupName).Properties 
          

            $sourceUri = $properties.storageProfile.osDisk.vhd.uri

            $uri = New-Object System.Uri($sourceUri)

            $vmStorageAccountName = $uri.Host.Split('.')[0]
            

            $storageAccounts = Find-AzureRmResource -ResourceType 'Microsoft.Storage/storageAccounts'  

            foreach($storageAccount in $storageAccounts){
                
                    if($storageAccount.ResourceName -eq $vmStorageAccountName){
                        
                         $vmStorageAccountRG = $storageAccount.ResourceGroupName
                    }
            }

             $vmStorageAccountKey = (Get-AzureRMStorageAccountKey -Name $vmStorageAccountName -ResourceGroupName $vmStorageAccountRG)[0].Value

             Write-Host 'Successfully fetched the storage account and storage account key for the VM.'

             Write-Host 'Stopping VM..' 

             Stop-AzureRMVM -Name $vm.Name -ResourceGroupName $vm.ResourceGroupName -Force | Out-Null

             Write-Host 'Successfully stopped VM'
        }
        
       break;
        
        
    }

}




$srcContext = New-AzureStorageContext –StorageAccountName $vmStorageAccountName -StorageAccountKey $vmStorageAccountKey 


$destContext = New-AzureStorageContext –StorageAccountName $labStorageAccountName -StorageAccountKey $labStorageAccountKey 

$copyHandle = Start-AzureStorageBlobCopy -srcUri $sourceUri -SrcContext $srcContext -DestContainer 'uploads' -DestBlob $vhdFileName -DestContext $destContext -Force

Write-Host "Copy started..."

$copyStatus = $copyHandle | Get-AzureStorageBlobCopyState 


While($copyStatus.Status -eq "Pending"){
$copyStatus = $copyHandle | Get-AzureStorageBlobCopyState 
$perComplete = ($copyStatus.BytesCopied/$copyStatus.TotalBytes)*100
Write-Progress -Activity "Copying blob..." -status "Percentage Complete" -percentComplete "$perComplete"
Start-Sleep 10
}

if($copyStatus.Status -eq "Success")
{
    Write-Host "$vhdFileName successfully copied to Lab $labName "

}

