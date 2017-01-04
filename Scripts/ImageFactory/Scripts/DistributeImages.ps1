param
(
    [Parameter(Mandatory=$true, HelpMessage="The location of the factory configuration files")]
    [string] $ConfigurationLocation,
    
    [Parameter(Mandatory=$true, HelpMessage="The ID of the subscription containing the images")]
    [string] $SubscriptionId,

    [Parameter(Mandatory=$true, HelpMessage="The name of the resource group")]
    [string] $ResourceGroupName,
    
    [Parameter(Mandatory=$true, HelpMessage="The name of the lab")]
    [string] $DevTestLabName,

    [Parameter(Mandatory=$true, HelpMessage="The number of script blocks we can run in parallel")]
    [int] $maxConcurrentJobs

)

#resolve any relative paths in ConfigurationLocation 
$ConfigurationLocation = (Resolve-Path $ConfigurationLocation).Path

$scriptFolder = Split-Path $Script:MyInvocation.MyCommand.Path
$modulePath = Join-Path $scriptFolder "DistributionHelpers.psm1"
Import-Module $modulePath
SelectSubscription $SubscriptionId

#get the list of labs from the json file
$labsList = Join-Path $ConfigurationLocation "Labs.json"
$labInfo = ConvertFrom-Json -InputObject (gc $labsList -Raw)
$labInfoCount = $labInfo.Labs.Length
Write-Output "Found $labInfoCount total labs"

logMessageForUnusedImagePaths $labInfo.Labs $ConfigurationLocation

#get the list of images
$sourceLabLocation = (Get-AzureRmResource -ResourceName $DevTestLabName -ResourceGroupName $ResourceGroupName -ResourceType 'Microsoft.DevTestLab/labs').Location
$labImages = Get-AzureRmResource -ResourceName $DevTestLabName -ResourceGroupName $ResourceGroupName -ResourceType 'Microsoft.DevTestLab/labs/customImages' -ApiVersion '2016-05-15' | Where-Object {$_.Properties.ProvisioningState -eq 'Succeeded'}
$labImageCount = $labImages.Count
Write-Output "Found $labImageCount images in lab $DevTestLabName"

$sourceImageInfos = @{}
$thingsToCopy = New-Object System.Collections.ArrayList

#iterate through the images in our lab and gather their storage keys once so we don't need to repeatedly grab them for the source lab later
foreach ($image in $labImages) {
    $foundTag = getTagValue $image 'ImagePath'
    if(!$foundTag) {
        continue;
    }
    
    $sourceVHDLocation = $image.Properties.Vhd.ImageName
    $uri = New-Object System.Uri($sourceVHDLocation)
    $vhdFileName = [System.IO.Path]::GetFileName($sourceVHDLocation)
    $osType = $image.Properties.Vhd.OsType
    $sysPrep = $image.Properties.Vhd.SysPrep
    $sourceStorageAccountName = $uri.Host.Split('.')[0]
    $sourceStorageAcct = (Get-AzureRMStorageAccountKey  -StorageAccountName $sourceStorageAccountName -ResourceGroupName $ResourceGroupName)
    
    # Azure Powershell version 1.3.2 or below - https://msdn.microsoft.com/en-us/library/mt607145.aspx
    $sourceStorageAccountKey = $sourceStorageAcct.Key1
    if ($sourceStorageAccountKey -eq $null) {
        # Azure Powershell version 1.4 or greater:
        $sourceStorageAccountKey = $sourceStorageAcct.Value[0]
    }

    $imageInfo = @{
        vhdLocation = $sourceVHDLocation
        storageAccountName = $sourceStorageAccountName
        storageAccountKey = $sourceStorageAccountKey
        fileName = $vhdFileName
        osType = $osType
        isVhdSysPrepped = $sysPrep
        imageDescription = $image.Properties.Description.Replace("Golden Image: ", "")
    }
    $sourceImageInfos[$image.Name] = $imageInfo
}

foreach ($targetLab in $labInfo.Labs){

    foreach ($image in $labImages) {
        $imageName = $image.Name
        $targetLabName = $targetLab.LabName
        $copyToLab = ShouldCopyImageToLab $targetLab $image

        if($copyToLab -eq $true) {
            Write-Output "Gathering data to copy $imageName to $targetLabName"

            $imagePathValue = getTagValue $image 'ImagePath'
            if(!$imagePathValue) {
                Write-Output "Ignoring $imageName because it has no ImagePath tag specified"
                continue;
            }
            
            $targetImageName = $imageName
 
            SelectSubscription $targetLab.SubscriptionId

            $lab = Get-AzureRmResource -ResourceType 'Microsoft.DevTestLab/labs' -ResourceName $targetLabName -ResourceGroupName $targetLab.ResourceGroup
            
            $existingTargetImage = Get-AzureRmResource -ResourceName $targetLabName -ResourceGroupName $targetLab.ResourceGroup -ResourceType 'Microsoft.DevTestLab/labs/customImages' -ApiVersion '2016-05-15' | Where-Object {$_.Name -eq $targetImageName}
            if($existingTargetImage){
                Write-Output "Not copying $imageName to $targetLabName because it already exists there as $targetImageName"
                continue;
            }

            $targetLabLocation = $lab.Location
            if($targetLabLocation -ne $sourceLabLocation){
                Write-Error "Lab location does not match. Source lab $DevTestLabName is in $sourceLabLocation and target lab $targetLabName is in $targetLabLocation"
                continue;
            }

            $targetStorageAccount = $lab.Properties.DefaultStorageAccount
            $splitStorageAcct = $targetStorageAccount.Split('/')
            $targetStorageAcctName = $splitStorageAcct[$splitStorageAcct.Length - 1]

            # Azure Powershell version 1.3.2 or below - https://msdn.microsoft.com/en-us/library/mt607145.aspx
            $targetStorageKey = (Get-AzureRMStorageAccountKey  -StorageAccountName $targetStorageAcctName -ResourceGroupName $lab.ResourceGroupName).Key1

            if ($targetStorageKey -eq $null) {
                # Azure Powershell version 1.4 or greater:
                $targetStorageKey = (Get-AzureRMStorageAccountKey  -StorageAccountName $targetStorageAcctName -ResourceGroupName $lab.ResourceGroupName).Value[0]
            }
            
            $sourceObject = $sourceImageInfos[$imageName]

            #make sure the destination has a generatedvhds container
            $destContext = New-AzureStorageContext -StorageAccountName $targetStorageAcctName -StorageAccountKey $targetStorageKey
            $existingContainer = Get-AzureStorageContainer -Context $destContext -Name 'generatedvhds' -ErrorAction Ignore
            if($existingContainer -eq $null) 
            {
                Write-Output 'Creating the generatedvhds container in the target storage account'
                New-AzureStorageContainer -Context $destContext -Name generatedvhds
            }

            $copyObject = @{
                imageName = $targetImageName
                sourceVHDLocation = $sourceObject.vhdLocation
                sourceStorageAccountName = $sourceObject.storageAccountName
                sourceStorageAccountKey = $sourceObject.storageAccountKey
                targetLabName = $targetLabName
                targetStorageKey = $targetStorageKey
                targetStorageAccountName = $targetStorageAcctName
                targetResourceGroup = $targetLab.ResourceGroup
                fileName = $sourceObject.fileName
                targetSubscriptionId = $targetLab.SubscriptionId
                osType = $sourceObject.osType
                isVhdSysPrepped = $sourceObject.isVhdSysPrepped
                imageDescription = $sourceObject.imageDescription
                imagePath = $imagePathValue
            }
            $thingsToCopy.Add($copyObject) | Out-Null
        }
    }
}

#kick off jobs to deploy all the VMs in parallel
$jobs = @()
SaveProfile

$copyVHDBlock = {
    Param($modulePath, $copyObject, $scriptFolder, $SubscriptionId)
    Import-Module $modulePath
    LoadProfile

    $srcContext = New-AzureStorageContext -StorageAccountName $copyObject.sourceStorageAccountName -StorageAccountKey $copyObject.sourceStorageAccountKey 
    $destContext = New-AzureStorageContext -StorageAccountName $copyObject.targetStorageAccountName -StorageAccountKey $copyObject.targetStorageKey
    $copyHandle = Start-AzureStorageBlobCopy -srcUri $copyObject.sourceVHDLocation -SrcContext $srcContext -DestContainer 'generatedvhds' -DestBlob $copyObject.fileName -DestContext $destContext -Force

    Write-Output ("Started copying " + $copyObject.fileName + " to " + $copyObject.targetStorageAccountName + " at " + (Get-Date -format "h:mm:ss tt"))
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
        Write-Output ($copyObject.fileName + " successfully copied to Lab " + $copyObject.targetLabName + " Deploying image template")
        $imageName = $copyObject.imageName

        #now that we have a VHD in the right storage account we need to create the actual image by deploying an ARM template
        $templatePath = Join-Path $scriptFolder "CreateImageFromVHD.json"
        $vhdUri = $destContext.BlobEndPoint + "generatedvhds/" + $copyObject.fileName

        SelectSubscription $copyObject.targetSubscriptionId

        Write-Output "Creating Image $imageName from template"
        $imagePath = $copyObject.imagePath
        $deployName = "Deploy-$imageName".Replace(" ", "").Replace(",", "")
        $deployResult = New-AzureRmResourceGroupDeployment -Name $deployName -ResourceGroupName $copyObject.targetResourceGroup -TemplateFile $templatePath -existingLabName $copyObject.targetLabName -existingVhdUri $vhdUri -imageOsType $copyObject.osType -isVhdSysPrepped $copyObject.isVhdSysPrepped -imageName $copyObject.imageName -imageDescription $copyObject.imageDescription -imagePath $imagePath

        if($deployResult.ProvisioningState -eq "Succeeded"){
            Write-Output "Successfully deployed image. Deleting copied VHD"
            Remove-AzureStorageBlob -Context $destContext -Container 'generatedvhds' -Blob $copyObject.fileName
            Write-Output "Copied VHD deleted"
        }
        else {
            Write-Error "Image deploy failed. We should stop now"
        }
    }
    else
    {
        Write-Error "finished without success"
    }
}

$copyCount = $thingsToCopy.Count
$jobIndex = 0
SelectSubscription $SubscriptionId

foreach ($copyObject in $thingsToCopy){
    #don't start more than $maxConcurrentJobs jobs at one time
    while ((Get-Job -State 'Running').Count -ge $maxConcurrentJobs){
        Write-Output "Throttling background tasks after starting $jobIndex of $copyCount tasks"
        Start-Sleep -Seconds 30
    }

    $jobIndex++
    Write-Output "Creating background task to distribute image $jobIndex of $copyCount"
    $jobs += Start-Job -ScriptBlock $copyVHDBlock -ArgumentList $modulePath, $copyObject, $scriptFolder, $SubscriptionId
}

if($jobs.Count -ne 0)
{
    try{
        Write-Output "Waiting for Image replication jobs to complete"
        foreach ($job in $jobs){
            Receive-Job $job -Wait | Write-Output
        }
    }
    finally{
        Remove-Job -Job $jobs
    }
}
else 
{
    Write-Output "No images to distribute"
}
