param
(
    [Parameter(Mandatory=$true, HelpMessage="The name of the DevTest Lab")]
    [string] $DevTestLabName
)

$ErrorActionPreference = "Stop"
$modulePath = Join-Path (Split-Path ($Script:MyInvocation.MyCommand.Path)) "DistributionHelpers.psm1"
Import-Module $modulePath

SaveProfile

$lab = Find-AzureRmResource -ResourceType 'Microsoft.DevTestLab/labs' | Where-Object { $_.Name -eq $DevTestLabName}
$labRgName= $lab.ResourceGroupName
$labStorageInfo = GetLabStorageInfo $lab
EnsureRootContainerExists $labStorageInfo
$existingImageInfos = GetImageInfosForLab $DevTestLabName

$labVMs = Get-AzureRmResource -ResourceName $DevTestLabName -ResourceGroupName $labRgName -ResourceType 'Microsoft.DevTestLab/labs/virtualMachines' -ApiVersion '2016-05-15' | Where-Object {$_.Properties.ProvisioningState -eq 'Succeeded'}
$jobs = @()
$copyObjects = New-Object System.Collections.ArrayList
try
{

    foreach($labVm in $labVMs)
    {
        #make sure we have a container in the storage account that matches the imagepath and date for this vhd
        $imagePath = getTagValue $labVm 'ImagePath'
        if(!$imagePath)
        {
            Write-Output "Ignoring $($labVm.Name) because it does not have the ImagePath tag"
            continue
        }

        $imageName = GetImageName $imagePath
        while ($existingImageInfos | Where-Object {$_.imageName -eq $imageName})
        {
            #There is an existing image with this name. We must be running the factory multiple times today. 
            $lastChar = $imageName[$imageName.Length - 1]
            $intVal = 0
            if ([System.Int32]::TryParse($vmName, [ref]$intVal))
            {
                #last character is a number (probably part of the date). Append an A
                $imageName = $imageName + 'A'
            }
            else
            {
                #last character is a letter. Increment the letter
                $newLastChar = [char](([int]$lastChar) + 1)
                $imageName = $imageName.SubString(0, ($imageName.Length - 1)) + $newLastChar
            }
        }

        $fileId = ([Guid]::NewGuid()).ToString()

        $computeVM = Get-AzureRmVM -Status | Where-Object -FilterScript {$_.Id -eq $labVM.Properties.computeId}
    
        if(!$computeVM)
        {
            Write-Error ("Didnt find a compute VM with ID " + $labVM.Properties.computeId)
        }

        #If the VM is still running that means it hasnt been sysprepped. dont try to copy the VHD because it will be locked.
        if($computeVM.PowerState -and $computeVM.PowerState -eq 'VM deallocated')
        {
            $isReady = $true
        }
        else
        {
            $foundPowerState = $computeVM.Statuses | Where-Object {$_.Code -eq 'PowerState/deallocated'}
            if($foundPowerState)
            {
                $isReady = $true
            }
            else
            {
                $isReady = $false
            }
        }

        if($isReady -ne $true)
        {
            Write-Output ("$($labVM.Name) because it is not currently stopped/deallocated so it will not be copied") 
            continue
        }

        #get a SAS token that's good for the next four hours. that should be enough time to complete all the disk copy jobs.
        Write-Output "Getting SAS token for disk $($computeVM.StorageProfile.OsDisk.Name) in resource group $($computeVM.ResourceGroupName)"
        $mdiskURL = (Grant-AzureRmDiskAccess -ResourceGroupName $computeVM.ResourceGroupName -DiskName $computeVM.StorageProfile.OsDisk.Name -Access Read -DurationInSecond 14400).AccessSAS
        if($mdiskURL -ne $null)
        {
            $copyInfo = @{
                computeRGName = $computeVM.ResourceGroupName
                computeDiskname = $computeVM.StorageProfile.OsDisk.Name
                sourceSASToken = $mdiskURL
                osType = $labVM.Properties.osType
                fileId = $fileId
                description = $labVM.Properties.notes.Replace("Golden Image: ", "")
                storageAcctName = $labStorageInfo.storageAcctName
                storageAcctKey = $labStorageInfo.storageAcctKey
                imagePath = $imagePath
                imageName = $imageName
            }

            $copyObjects.Add($copyInfo)
        }
        else
        {
            Write-Error "Unable to get SAS token for disk $($computeVM.StorageProfile.OsDisk.Name) in resource group $($computeVM.ResourceGroupName)"
        }
    }

    $storeVHDBlock = {
        Param($modulePath, $copyObject)
        Import-Module $modulePath
        LoadProfile
    
        $vhdFileName = $copyObject.fileId + ".vhd"
        $jsonFileName = $copyObject.fileId + ".json"
        $jsonFilePath = Join-Path $env:TEMP $jsonFileName
        $imageName = $copyObject.imageName
        Write-Output "Storing image: $imageName"
        $vhdInfo = @{
            imageName = $imageName
            imagePath = $copyObject.imagePath
            description = $copyObject.description
            osType = $copyObject.osType
            vhdFileName = $vhdFileName
            timestamp = (Get-Date).ToUniversalTime().ToString()
        }
    
        ConvertTo-Json -InputObject $vhdInfo | Out-File $jsonFilePath

        $storageContext = New-AzureStorageContext -StorageAccountName $copyObject.storageAcctName -StorageAccountKey $copyObject.storageAcctKey

        Set-AzureStorageBlobContent -Context $storageContext -File $jsonFilePath -Container 'imagefactoryvhds'
    
        Write-Output "Starting vhd copy..."
        $copyHandle = Start-AzureStorageBlobCopy -AbsoluteUri $copyObject.sourceSASToken -DestContainer 'imagefactoryvhds' -DestBlob $vhdFileName -DestContext $storageContext -Force

        Write-Output ("Started copy of " + $copyObject.computeDiskname + " at " + (Get-Date -format "h:mm:ss tt"))
        $copyStatus = $copyHandle | Get-AzureStorageBlobCopyState 
        $statusCount = 0

        While($copyStatus.Status -eq "Pending"){
            $copyStatus = $copyHandle | Get-AzureStorageBlobCopyState 
            [int]$perComplete = ($copyStatus.BytesCopied/$copyStatus.TotalBytes)*100
            Write-Progress -Activity "Copying blob..." -status "Percentage Complete" -percentComplete "$perComplete"

            if($perComplete -gt $statusCount){
                $statusCount = [math]::Ceiling($perComplete) + 3
                Write-Output "%$perComplete percent complete"
            }

            Start-Sleep 45
        }
        if($copyStatus.Status -eq "Success")
        {
            Write-Output ("Successfully copied " + $copyObject.computeDiskname + " at " + (Get-Date -format "h:mm:ss tt"))
        }
        else
        {
            if($copyStatus)
            {
                Write-Output $copyStatus
                Write-Error ("Copy Status should be Success but is reported as " + $copyStatus.Status)
            }
            else
            {
                Write-Error "There is no copy status"
            }
        }
    }

    foreach ($copyObject in $copyObjects){
        $jobIndex++
        Write-Output "Creating background task to store VHD $jobIndex of $($copyObjects.Count)"
        $jobs += Start-Job -ScriptBlock $storeVHDBlock -ArgumentList $modulePath, $copyObject
    }
    
    if($jobs.Count -ne 0)
    {
        Write-Output "Waiting for VHD replication jobs to complete"
        foreach ($job in $jobs){
            Receive-Job $job -Wait | Write-Output
        }
        Remove-Job -Job $jobs
    }
    else 
    {
        Write-Output "No VHDs to replicate"
    }
}
finally
{
    foreach ($copyObject in $copyObjects)
    {
        Write-Output "Reverting lock on disk $($copyObject.computeDiskname) in resource group $($copyObject.computeRGName)"
        Revoke-AzureRmDiskAccess -ResourceGroupName $copyObject.computeRGName -DiskName $copyObject.computeDiskname
        
    }
}
Write-Output 'Finished storing sysprepped VHDs'