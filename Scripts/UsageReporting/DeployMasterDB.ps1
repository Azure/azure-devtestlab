<#

.SYNOPSIS

This deploys the MasterDB.bacpac

.PARAMETER SubscriptionId

The subscription id that the resource group is created in.

.PARAMETER ResourceGroup

The name of the resource group

.NOTES

The script assumes that the ARM template has been successfully deployed.

#>

[CmdletBinding()]
Param(    
    [Parameter(Mandatory = $true)]  $SubscriptionId,
    [Parameter(Mandatory = $true)]  $ResourceGroupName,    
    [Parameter(Mandatory = $true)]  $sqlSrvName,
    [Parameter(Mandatory = $true)]  $sqlSrvAdmin,
    [Parameter(Mandatory = $true)]  $sqlSrvAdminPwd
 )

 #Login to Azure
 Login-AzureRmAccount
 
 #Set temp container
 $ContainerName = 'masterdtlusage'

 # Set the appropriate subscription where the lab exists.
 Set-AzureRmContext -SubscriptionId $SubscriptionId | Out-Null

# Find storage source we need to use in the resource group
$storageAcct =  Get-AzureRmResource `
    -ResourceGroupName $ResourceGroupName `
    -ResourceType 'Microsoft.Storage/storageAccounts'

$fileMasterDB = "https://github.com/Azure/azure-devtestlab/blob/usageReporting/Scripts/UsageReporting/MasterDB.bacpac?raw=true"

$localfile = "C:\dbtemp\masterdb.bacpac"

New-Item -Path "C:\dbtemp" -ItemType Directory

#Download file locally
$WebClient = New-Object System.Net.WebClient
$WebClient.DownloadFile($fileMasterDB,$localfile)


$storageAcctName = $storageAcct.Name

Set-AzureRmCurrentStorageAccount -ResourceGroupName $ResourceGroupName -Name $storageAcctName
#$storageContext = New-AzureStorageContext -StorageAccountName $storageAcctName -Anonymous -Protocol 'http'

#Create a new container.
New-AzureStorageContainer -Name $ContainerName -Permission Off

# Upload a blob into a container.
Set-AzureStorageBlobContent -Container $ContainerName -File $localfile
   

$importRequest = New-AzureRmSqlDatabaseImport -ResourceGroupName $ResourceGroupName `
    -ServerName $sqlSrvName `
    -DatabaseName $sqlSrvDbName `
    -DatabaseMaxSizeBytes "262144000" `
    -StorageKeyType "StorageAccessKey" `
    -StorageKey $(Get-AzureRmStorageAccountKey -ResourceGroupName $ResourceGroupName -StorageAccountName $storageAcctName).Value[0] `
    -StorageUri "http://$storageAcctName.blob.core.windows.net/$ContainerName/masterdb.bacpac" `
    -Edition "Standard" `
    -ServiceObjectiveName "P6" `
    -AdministratorLogin $sqlSrvAdmin `
    -AdministratorLoginPassword $(ConvertTo-SecureString -String $sqlSrvAdminPwd -AsPlainText -Force)

    