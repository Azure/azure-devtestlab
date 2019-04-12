param
(
    [Parameter(Mandatory=$true, HelpMessage="The location of the factory configuration files")]
    [string] $ConfigurationLocation,
    
    [Parameter(Mandatory=$true, HelpMessage="The ID of the subscription containing the Image Factory")]
    [string] $SubscriptionId,
    
    [Parameter(Mandatory=$true, HelpMessage="The name of the Image Factory DevTest Lab")]
    [string] $DevTestLabName,

	[Parameter(Mandatory=$true, HelpMessage="The number of images to save")]
    [int] $ImagesToSave
)

function CleanFilesInLabStorageAccount($DevTestLabName, $ImagesToSave, $goldenImagesFolder, $goldenImageFiles)
{
    $sourceImageInfos = GetImageInfosForLab $DevTestLabName

    $thingsToDelete = $sourceImageInfos | Group-Object {$_.imagePath} | 
                                        ForEach-Object {$_.Group | 
                                        Sort-Object timestamp -Descending | 
                                        Select-Object -Skip $ImagesToSave}

    foreach($imageInfo in $sourceImageInfos)
    {
        $filePath = Join-Path $goldenImagesFolder $imageInfo.imagePath
        $existingFile = $goldenImageFiles | Where-Object {$_.FullName -eq $filePath}
        if(!$existingFile)
        {
            Write-Output "Deleting image $($imageInfo.imageName) because the json file has been removed"
            $thingsToDelete = [Array](([Array]$thingsToDelete) + $imageInfo)
        }
    }


    if($thingsToDelete -and $thingsToDelete.Count -gt 0)
    {
        Write-Output "Found $($thingsToDelete.Count) ImageInfos to delete in the $storageAcctName storage account"
        $rootContainerName = 'imagefactoryvhds'
        $sourceLab = Find-AzureRmResource -ResourceType 'Microsoft.DevTestLab/labs' | Where-Object { $_.Name -eq $DevTestLabName}
        $labStorageInfo = GetLabStorageInfo $sourceLab
        $storageAcctName = $labStorageInfo.storageAcctName
        $storageContext = New-AzureStorageContext -StorageAccountName $storageAcctName -StorageAccountKey $labStorageInfo.storageAcctKey

        foreach($thingToDelete in $thingsToDelete)
        {
            Write-Output "Deleting image $($thingToDelete.imageName) from $DevTestLabName storage account $storageAcctName"

            $vhdBlobName = $thingToDelete.vhdFileName
            Write-Output "  Deleting $vhdBlobName"
            Remove-AzureStorageBlob -Context $storageContext -Container $rootContainerName -Blob $vhdBlobName -Force

            $jsonBlobName = $vhdBlobName.Replace('.vhd', '.json')
            Write-Output "  Deleting $jsonBlobName"
            Remove-AzureStorageBlob -Context $storageContext -Container $rootContainerName -Blob $jsonBlobName -Force
        }
    }
    else
    {
        Write-Output "No files to delete in the $storageAcctName storage account"
    }
}


#resolve any relative paths in ConfigurationLocation 
$ConfigurationLocation = (Resolve-Path $ConfigurationLocation).Path

$modulePath = Join-Path (Split-Path ($Script:MyInvocation.MyCommand.Path)) "DistributionHelpers.psm1"
Import-Module $modulePath
SaveProfile
$goldenImagesFolder = Join-Path $ConfigurationLocation "GoldenImages"
$goldenImageFiles = Get-ChildItem $goldenImagesFolder -Recurse -Filter "*.json" | Select-Object FullName

CleanFilesInLabStorageAccount $DevTestLabName $ImagesToSave $goldenImagesFolder $goldenImageFiles

$jobs = @()

# Script block for deleting images
$deleteImageBlock = {
    Param($modulePath, $imageToDelete)
    Import-Module $modulePath
    LoadProfile

    SelectSubscription $imageToDelete.SubscriptionId
    deleteImage $imageToDelete.ResourceGroupName $imageToDelete.ResourceName
}

# Get the list of labs that we have distributed images to
$labsList = Join-Path $ConfigurationLocation "Labs.json"
$labInfo = ConvertFrom-Json -InputObject (gc $labsList -Raw)
$ResourceGroupName = (Find-AzureRmResource -ResourceType 'Microsoft.DevTestLab/labs' | Where-Object { $_.Name -eq $DevTestLabName}).ResourceGroupName

# Add our 'current' lab (the factory lab) to the list of labs we're going to iterate through
$factorylabInfo = (New-Object PSObject |
   Add-Member -PassThru NoteProperty ResourceGroup $ResourceGroupName |
   Add-Member -PassThru NoteProperty SubscriptionId $SubscriptionId |
   Add-Member -PassThru NoteProperty Labname $DevTestLabName
)

$labInfo.Labs = ($labInfo.Labs + $factorylabInfo)
$labInfo | ConvertTo-Json | Write-Output
$sortedLabList = $labInfo.Labs | Sort-Object {$_.SubscriptionId}

# Iterate through all the labs
foreach ($selectedLab in $sortedLabList){

    # Get the list of images in the current lab
    SelectSubscription $selectedLab.SubscriptionId
    $selectedLabRG = (Find-AzureRmResource -ResourceType 'Microsoft.DevTestLab/labs' | Where-Object { $_.Name -eq $selectedLab.LabName}).ResourceGroupName
    $allImages = Get-AzureRmResource -ResourceName $selectedLab.LabName -ResourceGroupName $selectedLabRG -ResourceType 'Microsoft.DevTestLab/labs/customImages' -ApiVersion '2016-05-15'
    # Get the images to delete (generated by factory + only old images for each group based on retension policy)
    $imageObjectsToDelete = $allImages | ?{$_.Tags } | ForEach-Object { New-Object -TypeName PSObject -Prop @{
                                    ResourceName=$_.ResourceName
                                    ResourceGroupName=$_.ResourceGroupName
                                    SubscriptionId=$_.SubscriptionId
                                    CreationDate=$_.Properties.CreationDate
                                    ImagePath=getTagValue $_ 'ImagePath'
                                 }} | 
                                 Group-Object {$_.ImagePath} |
                                 ForEach-Object {$_.Group | Sort-Object CreationDate -Descending | Select-Object -Skip $ImagesToSave}

    # Delete the custom images we found in the search above
    foreach ($imageToDelete in $imageObjectsToDelete) {
        $jobs += Start-Job -Name $imageToDelete.ResourceName -ScriptBlock $deleteImageBlock -ArgumentList $modulePath, $imageToDelete
    }

    foreach($image in $allImages){
        #If this image is for an ImagePath that no longer exists then delete it. They must have removed this image from the factory
        $imagePath = getTagValue $image 'ImagePath'
        $resName = $image.ResourceName

        if($imagePath) {
            $filePath = Join-Path $goldenImagesFolder $imagePath
            $existingFile = $goldenImageFiles | Where-Object {$_.FullName -eq $filePath}
            if(!$existingFile){
                #The GoldenImage template for this image has been deleted. We should delete this image (unless we are already deleting it from previous check)
                $alreadyDeletingImage = $imageObjectsToDelete | Where-Object {$_.ResourceName -eq $resName }
                if($alreadyDeletingImage){
                    Write-Output "Image $resName is for a removed GoldenImage and has also been expired"
                }
                else {
                    Write-Output "Image $resName is for a removed GoldenImage. Starting job to remove the image."
                    $jobs += Start-Job -Name $image.ResourceName -ScriptBlock $deleteImageBlock -ArgumentList $modulePath, $image
                }
            }
            else{
                #if this is an image from a target lab, make sure it has not been removed from the labs.json file
                $labName = $selectedLab.LabName
                if($labName -ne $DevTestLabName){
                    $shouldCopyToLab = ShouldCopyImageToLab -lab $selectedLab -image $imagePath
                    if(!$shouldCopyToLab){
                        Write-Output "Image $resName is has been removed from Labs.json for $labName. Starting job to remove the image."
                        $jobs += Start-Job -Name $image.ResourceName -ScriptBlock $deleteImageBlock -ArgumentList $modulePath, $image
                    }
                }
            }
        }
        else{
            Write-Warning "Image $resName is being ignored because it does not have the ImagePath tag"
        }
    }
}


if($jobs.Count -ne 0)
{
    Write-Output "Waiting for Image deletion jobs to complete"
    foreach ($job in $jobs){
        Receive-Job $job -Wait | Write-Output
    }
    Remove-Job -Job $jobs
}
else 
{
    Write-Output "No images to delete!"
}

