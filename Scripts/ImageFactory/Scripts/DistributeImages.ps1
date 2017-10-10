param
(
    [Parameter(Mandatory=$true, HelpMessage="The location of the factory configuration files")]
    [string] $ConfigurationLocation,
    
    [Parameter(Mandatory=$true, HelpMessage="The ID of the subscription containing the images")]
    [string] $SubscriptionId,
    
    [Parameter(Mandatory=$true, HelpMessage="The name of the lab")]
    [string] $DevTestLabName,

    [Parameter(Mandatory=$true, HelpMessage="The number of script blocks we can run in parallel")]
    [int] $maxConcurrentJobs
)

function logMessageForUnusedImagePaths($labs, $configLocation)
{
    #iterate through each of the ImagePath entries in the lab and make sure that it points to at least one existing json file
    $goldenImagesFolder = Join-Path $configLocation "GoldenImages"
    $goldenImageFiles = Get-ChildItem $goldenImagesFolder -Recurse -Filter "*.json" | Select-Object FullName
    foreach ($lab in $labs){
        foreach ($labImagePath in $lab.ImagePaths){
            $filePath = Join-Path $goldenImagesFolder $labImagePath
            $matchingImages = $goldenImageFiles | Where-Object {$_.FullName.StartsWith($filePath,"CurrentCultureIgnoreCase")}
            if($matchingImages.Count -eq 0){
                $labName = $lab.LabName
                Write-Error "The Lab named $labName contains an ImagePath entry $labImagePath which does not point to any existing files in the GoldenImages folder."
            }
        }
    }
}

function logErrorForUnusedImages($labs, $configLocation)
{
    #iterate through each of the ImagePath entries in the lab and make sure that it points to at least one existing json file
    $goldenImagesFolder = Join-Path $configLocation "GoldenImages"
    $goldenImageFiles = Get-ChildItem $goldenImagesFolder -Recurse -Filter "*.json" | Select-Object FullName
    foreach($goldenImage in $goldenImageFiles)
    {
        #find any lab that references this image. If we dont find one, log an error.
        $foundLab = $false
        $imageRelativePath = $goldenImage.FullName.Substring($goldenImagesFolder.Length)
        if($imageRelativePath.StartsWith('\'))
        {
            $imageRelativePath = $imageRelativePath.Substring(1)
        }
        $imageRelativePath = $imageRelativePath.Replace('\', '/')

        foreach ($lab in $labs){
            if(!$foundLab)
            {
                foreach ($labImagePath in $lab.ImagePaths){
                    if($imageRelativePath.StartsWith($labImagePath))
                    {
                        $foundLab = $true
                        break
                    }
                }
            }
        }

        if(!$foundLab)
        {
            Write-Warning "Labs.json does not include any labs that reference $($goldenImage.FullName)"
        }
    }
}

$ErrorActionPreference = 'Continue'
#resolve any relative paths in ConfigurationLocation 
$ConfigurationLocation = (Resolve-Path $ConfigurationLocation).Path

$scriptFolder = Split-Path $Script:MyInvocation.MyCommand.Path
$modulePath = Join-Path $scriptFolder "DistributionHelpers.psm1"
Import-Module $modulePath
SelectSubscription $SubscriptionId

SaveProfile

$sourceLab = Find-AzureRmResource -ResourceType 'Microsoft.DevTestLab/labs' | Where-Object { $_.Name -eq $DevTestLabName}
$labStorageInfo = GetLabStorageInfo $sourceLab
$sourceImageInfos = GetImageInfosForLab $DevTestLabName
$thingsToCopy = New-Object System.Collections.ArrayList

$labsList = Join-Path $ConfigurationLocation "Labs.json"
$labInfo = ConvertFrom-Json -InputObject (gc $labsList -Raw)
logMessageForUnusedImagePaths $labInfo.Labs $ConfigurationLocation
logErrorForUnusedImages $labInfo.Labs $ConfigurationLocation

Write-Output "Found $($labInfo.Labs.Length) target labs"
$sortedLabList = $labInfo.Labs | Sort-Object {$_.SubscriptionId}

foreach ($targetLabInfo in $sortedLabList){

    foreach ($sourceImage in $sourceImageInfos) {
        $targetLabName = $targetLabInfo.LabName
        $copyToLab = ShouldCopyImageToLab $targetLabInfo $sourceImage.imagePath

        if($copyToLab -eq $true) {
            SelectSubscription $targetLabInfo.SubscriptionId
            $targetLabRG = (Find-AzureRmResource -ResourceType 'Microsoft.DevTestLab/labs' | Where-Object { $_.Name -eq $targetLabName}).ResourceGroupName
            if(!$targetLabRG)
            {            
                Write-Error ("Unable to find a lab named $targetLabName in subscription with id " + $targetLabInfo.SubscriptionId)
            }

            $targetLab = Get-AzureRmResource -ResourceType 'Microsoft.DevTestLab/labs' -ResourceName $targetLabName -ResourceGroupName $targetLabRG
            $targetLabStorageInfo = GetLabStorageInfo $targetLab

            $existingTargetImage = Get-AzureRmResource -ResourceName $targetLabName -ResourceGroupName $targetLabRG -ResourceType 'Microsoft.DevTestLab/labs/customImages' -ApiVersion '2016-05-15' | Where-Object {$_.Name -eq $sourceImage.imageName}
            if($existingTargetImage){
                Write-Output "$($sourceImage.imageName) already exists in $targetLabName and will not be overwritten"
                continue;
            }

            if($targetLab.Location -ne $sourceLab.Location){
                Write-Error "Lab location does not match. Source lab $DevTestLabName is in $($sourceLab.Location) and target lab $targetLabName is in $($targetLab.Location)"
                continue;
            }

            Write-Output "Gathering data to copy $($sourceImage.imagePath) to $targetLabName"
            $copyObject = @{
                imageName = $sourceImage.imageName
                imageDescription = $sourceImage.description
                imagePath = $sourceImage.imagePath
                osType = $sourceImage.osType
                isVhdSysPrepped = $true
                vhdFileName = $sourceImage.vhdFileName
                sourceStorageAccountName = $labStorageInfo.storageAcctName
                sourceStorageKey = $labStorageInfo.storageAcctKey
                sourceResourceGroup = $labStorageInfo.resourceGroupName
                sourceSubscriptionId = $SubscriptionId
                targetLabName = $targetLabName
                targetStorageAccountName = $targetLabStorageInfo.storageAcctName
                targetStorageKey = $targetLabStorageInfo.storageAcctKey
                targetResourceGroup = $targetLabStorageInfo.resourceGroupName
                targetSubscriptionId = $targetLab.SubscriptionId
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
    
    $srcContext = New-AzureStorageContext -StorageAccountName $copyObject.sourceStorageAccountName -StorageAccountKey $copyObject.sourceStorageKey 
    $srcURI = $srcContext.BlobEndPoint + "imagefactoryvhds/" + $copyObject.vhdFileName
    $destContext = New-AzureStorageContext -StorageAccountName $copyObject.targetStorageAccountName -StorageAccountKey $copyObject.targetStorageKey
    New-AzureStorageContainer -Context $destContext -Name 'imagefactoryvhds' -ErrorAction Ignore
    $copyHandle = Start-AzureStorageBlobCopy -srcUri $srcURI -SrcContext $srcContext -DestContainer 'imagefactoryvhds' -DestBlob $copyObject.vhdFileName -DestContext $destContext -Force

    Write-Output ("Started copying " + $copyObject.vhdFileName + " to " + $copyObject.targetStorageAccountName + " at " + (Get-Date -format "h:mm:ss tt"))
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
        $imageName = $copyObject.imageName
        Write-Output ($copyObject.vhdFileName + " successfully copied to Lab " + $copyObject.targetLabName + ". Deploying image $imageName")

        #now that we have a VHD in the right storage account we need to create the actual image by deploying an ARM template
        $templatePath = Join-Path $scriptFolder "CreateImageFromVHD.json"
        $vhdUri = $destContext.BlobEndPoint + "imagefactoryvhds/" + $copyObject.vhdFileName

        SelectSubscription $copyObject.targetSubscriptionId

        $imagePath = $copyObject.imagePath
        $deployName = "Deploy-$imageName"
        $deployResult = New-AzureRmResourceGroupDeployment -Name $deployName -ResourceGroupName $copyObject.targetResourceGroup -TemplateFile $templatePath -existingLabName $copyObject.targetLabName -existingVhdUri $vhdUri -imageOsType $copyObject.osType -isVhdSysPrepped $copyObject.isVhdSysPrepped -imageName $copyObject.imageName -imageDescription $copyObject.imageDescription -imagePath $imagePath

        #delete the deployment information so that we dont use up the total deployments for this resource group
        Remove-AzureRmResourceGroupDeployment -ResourceGroupName $copyObject.targetResourceGroup -Name $deployName  -ErrorAction SilentlyContinue | Out-Null

        if($deployResult.ProvisioningState -eq "Succeeded"){
            Write-Output "Successfully deployed image. Deleting copied VHD"
            Remove-AzureStorageBlob -Context $destContext -Container 'imagefactoryvhds' -Blob $copyObject.vhdFileName
            Write-Output "Copied VHD deleted"
        }
        else {
            Write-Error "Image deploy failed. We should stop now"
        }
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
    Write-Output "Waiting for $($jobs.Count) Image replication jobs to complete"
    foreach ($job in $jobs){
        Receive-Job $job -Wait | Write-Output
    }
    Remove-Job -Job $jobs
}
else 
{
    Write-Output "No images to distribute"
}

foreach ($copyInfo in $thingsToCopy)
{
    SelectSubscription $copyInfo.targetSubscriptionId
    #remove the root container from the target labs since we dont need it any more
    $targetLab = Find-AzureRmResource -ResourceType 'Microsoft.DevTestLab/labs' | Where-Object { $_.Name -eq $copyInfo.targetLabName}
    $targetStorageInfo = GetLabStorageInfo $targetLab
    $storageContext = New-AzureStorageContext -StorageAccountName $targetStorageInfo.storageAcctName -StorageAccountKey $targetStorageInfo.storageAcctKey
    $rootContainerName = 'imagefactoryvhds'
    $rootContainer = Get-AzureStorageContainer -Context $storageContext -Name $rootContainerName -ErrorAction Ignore
    if($rootContainer -ne $null) 
    {
        Write-Output "Deleting the $rootContainerName container in the target storage account"
        Remove-AzureStorageContainer -Context $storageContext -Name $rootContainerName -Force
    }

}

Write-Output "Distribution of $($jobs.Count) images is complete"
