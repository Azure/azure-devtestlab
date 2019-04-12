function SelectSubscription($subId){
    # switch to another subscription assuming it's not the one we're already on
    if((Get-AzureRmContext).Subscription.Id -ne $subId){
        Write-Output "Switching to subscription $subId"
        Set-AzureRmContext -SubscriptionId $subId | Out-Null
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

function ShouldCopyImageToLab ($lab, $imagePathValue)
{
    $retval = $false

    foreach ($labImagePath in $lab.ImagePaths) {
        if ($imagePathValue.StartsWith($labImagePath.Replace("/", "\"))) {
            $retVal = $true;
            break;
        }
    }
    $retval
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
    
    Save-AzureRmContext -Path $profilePath
}

function LoadProfile {
    $scriptFolder = Split-Path $Script:MyInvocation.MyCommand.Path
    Import-AzureRmContext -Path (Join-Path $scriptFolder "profile.json") | Out-Null
}

function deleteImage ($resourceGroupName, $resourceName)
{
    Write-Output "##[section]Deleting Image: $resourceName"
    Remove-AzureRmResource -ResourceName $resourceName -ResourceGroupName $resourceGroupName -ResourceType 'Microsoft.DevTestLab/labs/customImages' -ApiVersion '2016-05-15' -Force
    Write-Output "##[section]Completed deleting $resourceName"
}

function GetImageName ($imagePathValue)
{
    $splitImagePath = $imagePathValue.Split('\')
    if($splitImagePath.Length -eq 1){
        #the image is directly in the GoldenImages folder. Just use the file name as the image name.
        $imagename = $splitImagePath[0]
    }
    else {
        #this image is in a folder within GoldenImages. Name the image <FolderName>  <fileName> with <FolderName> set to the name of the folder that contains the image
        $segmentCount = $splitImagePath.Length
        $imagename = $splitImagePath[$segmentCount - 2] + "_" + $splitImagePath[$segmentCount - 1]
    }

    #clean up some special characters in the image name and stamp it with todays date
    $imagename = $imagename.Replace(".json", "").Replace(".", "_").Replace(" ", "-")
    $imagename = $imagename +  "-" + (Get-Date -Format 'MMM-d-yyyy')
    return $imagename
}

function GetLabStorageInfo ($lab)
{
    $labRgName= $lab.ResourceGroupName
    $sourceLab = Get-AzureRmResource -ResourceName $lab.Name -ResourceGroupName $labRgName -ResourceType 'Microsoft.DevTestLab/labs'
    $storageAcctValue = $sourceLab.Properties.artifactsStorageAccount
    $storageAcctName = $storageAcctValue.Substring($storageAcctValue.LastIndexOf('/') + 1)

    $storageAcct = (Get-AzureRMStorageAccountKey  -StorageAccountName $storageAcctName -ResourceGroupName $labRgName)
    # Azure Powershell version 1.3.2 or below - https://msdn.microsoft.com/en-us/library/mt607145.aspx
    $storageAcctKey = $storageAcct.Key1
    if ($storageAcctKey -eq $null) {
        # Azure Powershell version 1.4 or greater:
        $storageAcctKey = $storageAcct.Value[0]
    }
    $result = @{
        resourceGroupName = $labRgName
        storageAcctName = $storageAcctName
        storageAcctKey = $storageAcctKey
    }
    return $result
}

function EnsureRootContainerExists ($labStorageInfo)
{
    $storageContext = New-AzureStorageContext -StorageAccountName $labStorageInfo.storageAcctName -StorageAccountKey $labStorageInfo.storageAcctKey
    $rootContainerName = 'imagefactoryvhds'
    $rootContainer = Get-AzureStorageContainer -Context $storageContext -Name $rootContainerName -ErrorAction Ignore
    if($rootContainer -eq $null) 
    {
        Write-Output "Creating the $rootContainerName container in the target storage account"
        $rootContainer = New-AzureStorageContainer -Context $storageContext -Name $rootContainerName
    }
}

function GetImageInfosForLab ($DevTestLabName) 
{
    $lab = Find-AzureRmResource -ResourceType 'Microsoft.DevTestLab/labs' | Where-Object { $_.Name -eq $DevTestLabName}
    $labRgName= $lab.ResourceGroupName
    $sourceLab = Get-AzureRmResource -ResourceName $DevTestLabName -ResourceGroupName $labRgName -ResourceType 'Microsoft.DevTestLab/labs'
    $storageAcctValue = $sourceLab.Properties.artifactsStorageAccount
    $storageAcctName = $storageAcctValue.Substring($storageAcctValue.LastIndexOf('/') + 1)

    $storageAcct = (Get-AzureRMStorageAccountKey  -StorageAccountName $storageAcctName -ResourceGroupName $labRgName)
    # Azure Powershell version 1.3.2 or below - https://msdn.microsoft.com/en-us/library/mt607145.aspx
    $storageAcctKey = $storageAcct.Key1
    if ($storageAcctKey -eq $null) {
        # Azure Powershell version 1.4 or greater:
        $storageAcctKey = $storageAcct.Value[0]
    }

    $storageContext = New-AzureStorageContext -StorageAccountName $storageAcctName -StorageAccountKey $storageAcctKey

    $rootContainerName = 'imagefactoryvhds'

    $jsonBlobs = Get-AzureStorageBlob -Context $storageContext -Container $rootContainerName -Blob '*json'

    Write-Host "Downloading $($jsonBlobs.Length) json files from storage account"
    $downloadFolder = Join-Path $env:TEMP 'ImageFactoryDownloads'
    if(Test-Path -Path $downloadFolder)
    {
        Remove-Item $downloadFolder -Recurse | Out-Null
    }
    New-Item -Path $downloadFolder -ItemType Directory | Out-Null
    $jsonBlobs | Get-AzureStorageBlobContent -Destination $downloadFolder | Out-Null

    $sourceImageInfos = @()

    $downloadedFileNames = Get-ChildItem -Path $downloadFolder
    foreach($file in $downloadedFileNames)
    {
        $imageObj = (gc $file.FullName -Raw) | ConvertFrom-Json
        $imageObj.timestamp = [DateTime]::Parse($imageObj.timestamp)
        $sourceImageInfos += $imageObj
    }

    return $sourceImageInfos
}
