function SelectSubscription($subId){
    # switch to another subscription assuming it's not the one we're already on
    if((Get-AzureRmContext).Subscription.SubscriptionId -ne $subId){
        Write-Output "Switching to subscription $subId"
        Select-AzureRmSubscription -SubscriptionId $subId | Out-Null
    }
}

function getTagValue($resource, $tagName){
    $result = $null
    if ($resource.Tags){
        $result = $resource.Tags | Where-Object {$_.Name -eq $tagName}
        if($result){
            $result = $result.Value
        }
        else {
            $result = $resource.Tags[$tagName]
        }
    }
    $result
}

function ShouldCopyImageToLab ($lab, $image)
{
    $retval = $false

    $imagePathTag = getTagValue $image 'ImagePath'
    if(!$imagePathTag) {
        #this image does not have the ImagePath tag. Dont copy it
        $retval = $false
    }
    else{
        foreach ($labImagePath in $lab.ImagePaths) {
            if ($imagePathTag.StartsWith($labImagePath.Replace("/", "\"))) {
                $retVal = $true;
                break;
            }
        }
    }
    $retval
}

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

function ConvertTo-Object {

	begin { $object = New-Object Object }

	process {

	$_.GetEnumerator() | ForEach-Object { Add-Member -inputObject $object -memberType NoteProperty -name $_.Name -value $_.Value }   

	}

	end { $object }

}

function SaveProfile {
    $profilePath = Join-Path $PSScriptRoot "profile.json"

    If (Test-Path $profilePath){
	    Remove-Item $profilePath
    }
    
    Save-AzureRmProfile -Path $profilePath
}

function LoadProfile {
    $scriptFolder = Split-Path $Script:MyInvocation.MyCommand.Path
    Select-AzureRmProfile -Path (Join-Path $scriptFolder "profile.json") | Out-Null
}

function deleteImage ($resourceGroupName, $resourceName)
{
    Write-Output "##[section]Deleting Image: $resourceName"
    Remove-AzureRmResource -ResourceName $resourceName -ResourceGroupName $resourceGroupName -ResourceType 'Microsoft.DevTestLab/labs/customImages' -ApiVersion '2016-05-15' -Force
    Write-Output "##[section]Completed deleting $resourceName"
}
