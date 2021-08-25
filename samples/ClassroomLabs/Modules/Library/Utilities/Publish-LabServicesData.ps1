<#
   Script gathers information of all labs, lab virtual machines and lab users for the current subscription.
   Data is save in a CSV file, which is uploaded to blob storage.
   Three storage containers are used.  
   1. For current properties of all labs in the subscription.
   2. For current properties of all lab virtual machines in the subscription, irregardless of what lab they are in.
   3. For current properties of all lab users in the subscription, irregardless of what lab they are in.
 #>
#IMPORTANT: Comment out parameter block if executing in an Azure Function with timer trigger
#param($timer)
param (
    [string] $StorageAccountResourceGroupName,
    [string] $StorageAccountName
)

$ErrorActionPreference = "Stop"

Set-StrictMode -Version 3.0
 
# ************************************************
# ************ FIELDS TO UPDATE ******************
# ************************************************
# If script is being run in a Azure Function environment,
#  we expected the storage account name and resource group to be application settings
if ([Environment]::GetEnvironmentVariable('StorageAccountResourceGroupName')) {
    $StorageAccountResourceGroupName = [Environment]::GetEnvironmentVariable('StorageAccountResourceGroupName')
}
if ([Environment]::GetEnvironmentVariable('StorageAccountName')) {
    $StorageAccountName = [Environment]::GetEnvironmentVariable('StorageAccountName')
}

# ************************************************

#Info for saving data to storage
# for lab information
$LabInfoPrefix = "labinfo"
$LabInfoContainerName = "$LabInfoPrefix-dailyexports"
$LabInfoBlobName = "$LabInfoPrefix-$((New-Guid).Guid).csv"
# for vm information
$VmInfoPrefix = "vminfo"
$VmInfoContainerName = "$VmInfoPrefix-dailyexports"
$VmInfoBlobName = "$VmInfoPrefix-$((New-Guid).Guid).csv"
# for user information
$UserInfoPrefix = "userinfo"
$UserInfoContainerName = "$UserInfoPrefix-dailyexports"
$UserInfoBlobName = "$UserInfoPrefix-$((New-Guid).Guid).csv"

# ************************************************
# ************************************************
# ************************************************

<#
Function writes contents of the data file to the blob container.
#>
function Write-ResourceInformation {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true)] [Microsoft.WindowsAzure.Commands.Common.Storage.LazyAzureStorageContext] $StorageAccountContext,
        [Parameter(Mandatory = $true)] [string] $ContainerName,
        [Parameter(Mandatory = $true)] [string] $BlobName,
        [Parameter(Mandatory = $true)] [System.IO.FileInfo] $DataFile
    )
    # Create the container if it doesn't already exist
    $container = Get-AzStorageContainer -Name $ContainerName -Context $StorageAccountContext -ErrorAction SilentlyContinue
    if (-not $container) {
        $container = New-AzStorageContainer -Name $ContainerName -Context $StorageAccountContext
    }

    # Upload the file to storage
    Set-AzStorageBlobContent -File $DataFile -Container $ContainerName -Blob $BlobName -Context $StorageAccountContext -Force

    Write-Host "Finished uploading $BlobName." 
}

# ************************************************

if ($env:FUNCTIONS_EXTENSION_VERSION) {
    #In Azure Functions environment,
    # Module must be uploaded as described in 
    # https://docs.microsoft.com/azure/azure-functions/functions-reference-powershell?tabs=portal#custom-modules
    Import-Module  Az.LabServices 
    Connect-AzAccount -Identity
}
else {
    if (-not (Get-Module -ListAvailable -Name Az.Accounts)) {
        Import-Module Az.Accounts
    }
    if (-not (Get-Module -ListAvailable -Name Az.Storage)) {
        Import-Module Az.Storage
    }
    Import-Module  ../Az.LabServices.psm1 -ErrorAction Continue
}


#Temporary CSV files for saving data that will be written to blob storage later
$LabInfoLocalOutputFile = New-TemporaryFile
$VmInfoLocalOutputFile = New-TemporaryFile
$UserInfoLocalOutputFile = New-TemporaryFile

#Get current subscription information from current context
#Connect-AzAccount -Identity

$subscriptionId = Get-AzContext | Select-Object -ExpandProperty Subscription | Select-Object -ExpandProperty Id

#Context used to save data to storage account
$ctx = (Get-AzStorageAccount -ResourceGroupName $StorageAccountResourceGroupName -Name $StorageAccountName).Context

$utcDate = (Get-Date).ToUniversalTime()

$labAccounts = Get-AzLabAccount
foreach ($labAccount in $labAccounts) {

    $labs = $labAccount | Get-AzLab
    foreach ($lab in $labs) {

        $labVMs = $lab | Get-AzLabVm

        # ************ Lab Information ************
        $details = [PSCustomObject] @{
            Date                     = $utcDate

            SubscriptionId           = $subscriptionId
            ResourceGroupName        = $lab.ResourceGroupName

            LabAccountName           = $labAccount.LabAccountName
            LabAccountId             = $labAccount.id

            LabName                  = $lab.LabName
            LabId                    = $lab.id
            LabMaximumNumberOfUsers  = $lab.properties.maxUsersInLab
            LabQuotaHours            = [System.Xml.XmlConvert]::ToTimeSpan($lab.properties.usageQuota).TotalHours
            LabLocation              = $lab.location

            SharedPasswordEnabled    = $lab.properties.sharedPasswordEnabled
            IdleShutdownMode         = $lab.properties.idleShutdownMode
            IdleGracePeriod          = $lab.properties.idleGracePeriod
            EnableDisconnectOnIdle   = $lab.properties.enableDisconnectOnIdle
            IdleOsGracePeriod        = $lab.properties.idleOsGracePeriod
            EnableNoConnectShutdown  = $lab.properties.enableNoConnectShutdown
            IdleNoConnectGracePeriod = $lab.properties.idleNoConnectGracePeriod
        }

        #This API has price and vm size information for a lab
        # We need to call directly since Az.LabServices doesn't expose this
        try {
            $url = "https://management.azure.com$($lab.id)/getLabPricingAndAvailability?api-version=2019-01-01-preview" 
            $labPricingInformation = Invoke-WebRequest $url `
                -Headers @{                    
                'Content-Type'  = 'application/json'                   
                'Authorization' = "Bearer $(Get-AzAccessToken | Select-Object -expand Token)"
            } `
            -Method POST | ConvertFrom-Json
         
            #Add pricing information for lab
            $details | Add-Member -Name "PricePerHour" -Value $labPricingInformation.price -MemberType NoteProperty
            $details | Add-Member -Name "PriceCurrencyCode" -Value $labPricingInformation.currencyCode -MemberType NoteProperty
            $details | Add-Member -Name "Geography" -Value $labPricingInformation.geography.localizedDisplayName -MemberType NoteProperty
      
            #Adding VM size details for the lab
            $details | Add-Member -Name "VmOperatingSystem" -Value $labPricingInformation.operatingSystemName -MemberType NoteProperty
            $details | Add-Member -Name "VmSize" -Value $labPricingInformation.size.localizedDisplayName -MemberType NoteProperty
            $details | Add-Member -Name "VmCoreCount" -Value $labPricingInformation.size.coresCount -MemberType NoteProperty
            $details | Add-Member -Name "VmMemoryInGb" -Value $labPricingInformation.size.memoryInGb -MemberType NoteProperty
            $details | Add-Member -Name "VmGpu" -Value $labPricingInformation.size.gpu -MemberType NoteProperty
        }
        catch {
            Write-Warning "Couldn't get pricing information for Lab Account '$($labAccount.LabAccountName)', Lab '$($lab.LabName)'" 
           #Write-Warning "Url is $url"
        }

        #Write Lab information to temporary file
        $details | Export-Csv -Path $LabInfoLocalOutputFile -NoTypeInformation -Append -Force
        Write-Host "Found details for Lab Account '$($labAccount.LabAccountName)', Lab '$($lab.LabName)'" 
  
        foreach ($labVm in $labVms) {       
            # ************ Vm Information ************
 
            $vmUsageTimeSpan = [System.Xml.XmlConvert]::ToTimeSpan($labVm.properties.totalUsage)
 
            #Format and record information for labVM
            $details = [PSCustomObject] @{
                Date              = $utcDate

                SubscriptionId    = $subscriptionId
                ResourceGroupName = $lab.ResourceGroupName

                LabAccountName    = $labAccount.LabAccountName
                LabAccountId      = $labAccount.id

                LabName           = $lab.LabName
                LabId             = $lab.id

                VmName            = $labVm.name
                VmId              = $labVm.Id
                VmUsageHours      = [System.Math]::Floor($vmUsageTimeSpan.TotalHours)
                VmUsageMinutes    = $vmUsageTimeSpan.Minutes
                VmUsageString     = $labVm.properties.totalUsage

                #Warning: Below properties contain personally identifiable information
                UserName          = if ($labVm.properties.psobject.Properties['claimedByUserName']) { $labVm.properties.claimedByUserName }
                UserPrincipal     = $labVm.UserPrincipal
                IsClaimed         = $labVm.properties.isClaimed   
            }

            #find user information if VM has been claimed
            $user = $lab | Get-AzLabUser | Where-Object { $_.name -ieq $labVm.UserPrincipal }
            if ($user) {
                #Warning: Below properties contain personally identifiable information              
                $details | Add-Member -Name "UserId" -Value $user.id -MemberType NoteProperty
                $details | Add-Member -Name "UserEmail" -Value $user.properties.email -MemberType NoteProperty
                
                $details | Add-Member -Name "UserUsageString" -Value $user.properties.totalUsage -MemberType NoteProperty
                $userUsageTimeSpan = [System.Xml.XmlConvert]::ToTimeSpan($user.properties.totalUsage)
                $details | Add-Member -Name "UserUsageHours" -Value $([System.Math]::Floor($userUsageTimeSpan.TotalHours)) -MemberType NoteProperty
                $details | Add-Member -Name "UserUsageMinutes" -Value $userUsageTimeSpan.Minutes -MemberType NoteProperty

                if ($user.properties.psobject.Properties['additionalUsageQuota']) { 
                    $userAdditionalQuotaTimeSpan = [System.Xml.XmlConvert]::ToTimeSpan($user.properties.additionalUsageQuota) 
                    $details | Add-Member -Name "UserAdditionalQuotaHours" -Value $userAdditionalQuotaTimeSpan.TotalHours -MemberType NoteProperty
                }
            }
        
            #Write vm info to temporary file
            $details | Export-Csv -Path $VmInfoLocalOutputFile -NoTypeInformation -Append -Force
            Write-Host "Found details for Lab Account '$($labAccount.LabAccountName)', Lab '$($lab.LabName)', VM '$($labVM.name)' " 

            # ************ User Information ************
            $usersInLab = $lab | Get-AzLabUser
            foreach ($user in $usersInLab) {
                $details = [PSCustomObject] @{
                    Date              = $utcDate
    
                    SubscriptionId    = $subscriptionId
                    ResourceGroupName = $lab.ResourceGroupName
    
                    LabAccountName    = $labAccount.LabAccountName
                    LabAccountId      = $labAccount.id
    
                    LabName           = $lab.LabName
                    LabId             = $lab.id
   
                    #Warning: Below properties contain personally identifiable information
                    UserName          = $user.name
                    UserId            = $user.id
                    UserEmail         = $user.properties.email
                }

                if ($user.properties.psobject.Properties['totalUsage']) {
                    $details | Add-Member -Name "UserUsageString" -Value $user.properties.totalUsage -MemberType NoteProperty
                    $userUsageTimeSpan = [System.Xml.XmlConvert]::ToTimeSpan($user.properties.totalUsage)
                    $details | Add-Member -Name "UserUsageHours" -Value $([System.Math]::Floor($userUsageTimeSpan.TotalHours)) -MemberType NoteProperty
                    $details | Add-Member -Name "UserUsageMinutes" -Value $userUsageTimeSpan.Minutes -MemberType NoteProperty
                }
                if ($user.properties.psobject.Properties['additionalUsageQuota']) { 
                    $userAdditionalQuotaTimeSpan = [System.Xml.XmlConvert]::ToTimeSpan($user.properties.additionalUsageQuota) 
                    $details | Add-Member -Name "UserAdditionalQuotaHours" -Value $userAdditionalQuotaTimeSpan.TotalHours -MemberType NoteProperty
                }

                #Write user info to temporary file
                $details | Export-Csv -Path $UserInfoLocalOutputFile -NoTypeInformation -Append -Force
                Write-Host "Found details for Lab Account '$($labAccount.LabAccountName)', Lab '$($lab.LabName)', User '$($user.name)' " 
            } 
        }
    }
}

#Record information in blob storage
Write-ResourceInformation -StorageAccountContext $ctx -ContainerName $LabInfoContainerName -BlobName $LabInfoBlobName -DataFile $LabInfoLocalOutputFile
Write-ResourceInformation -StorageAccountContext $ctx -ContainerName $VmInfoContainerName -BlobName $VmInfoBlobName -DataFile $VmInfoLocalOutputFile
Write-ResourceInformation -StorageAccountContext $ctx -ContainerName $UserInfoContainerName -BlobName $UserInfoBlobName -DataFile $UserInfoLocalOutputFile

#Write an identifiable blog with the latest information.
# Warning: This will result in duplicate information and should be accounted for 
# if using these containers as a data source for reports
Write-ResourceInformation -StorageAccountContext $ctx -ContainerName $LabInfoContainerName -BlobName "$LabInfoPrefix-latest.csv" -DataFile $LabInfoLocalOutputFile
Write-ResourceInformation -StorageAccountContext $ctx -ContainerName $VmInfoContainerName -BlobName "$VmInfoPrefix-latest.csv" -DataFile $VmInfoLocalOutputFile
Write-ResourceInformation -StorageAccountContext $ctx -ContainerName $UserInfoContainerName -BlobName "$UserInfoPrefix-latest.csv" -DataFile $UserInfoLocalOutputFile

#Clean up temporary files
@($LabInfoLocalOutputFile, $VmInfoLocalOutputFile, $UserInfoLocalOutputFile) | ForEach-object { Remove-Item -Path $_ -Force }