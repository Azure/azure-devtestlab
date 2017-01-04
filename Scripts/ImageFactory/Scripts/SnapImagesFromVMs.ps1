param
(
    [Parameter(Mandatory=$true, HelpMessage="The name of the DevTest Lab")]
    [string] $DevTestLabName,

    [Parameter(Mandatory=$true, HelpMessage="The name of the Resource Group that holds the DevTest Lab")]
    [string] $ResourceGroupName
)

$modulePath = Join-Path (Split-Path ($Script:MyInvocation.MyCommand.Path)) "DistributionHelpers.psm1"
Import-Module $modulePath

SaveProfile

$jobs = @()

# Script block for deleting images
$createImageBlock = {
    Param($modulePath, $imageToCreate)
    Import-Module $modulePath
    LoadProfile

    $imageName = $imageToCreate.imagename 
    $deployName = "Deploy-$imagename".Replace(" ", "").Replace(",", "")
    Write-Output "Creating Image $imagename from template"
    $deployResult = New-AzureRmResourceGroupDeployment -Name $deployName -ResourceGroupName $imageToCreate.ResourceGroupName -TemplateFile $imageToCreate.templatePath -existingLabName $imageToCreate.DevTestLabName -existingVMResourceId $imageToCreate.vmResourceId -imageName $imagename -imageDescription $imageToCreate.imageDescription -imagePath $imageToCreate.imagePath -osType $imageToCreate.osType

    if($deployResult.ProvisioningState -eq "Succeeded"){
        Write-Output "Successfully deployed image"
        $foundimage = (Get-AzureRmResource -ResourceName $imageToCreate.DevTestLabName -ResourceGroupName $imageToCreate.ResourceGroupName -ResourceType 'Microsoft.DevTestLab/labs/customImages' -ApiVersion '2016-05-15') | Where-Object {$_.name -eq $imagename}
        if($foundimage.Count -eq 0){
            Write-Warning "$imagename was not created successfully"
        }
    }

    if($deploySuccess -eq $false){
        Write-Error "Creation of Image $imageName failed"
    }
}


# Get a pointer to all the VMs in the subscription
$allVms = Get-AzureRmResource -ResourceGroupName $ResourceGroupName -ResourceType Microsoft.DevTestLab/labs/virtualmachines -ResourceName $DevTestLabName -ApiVersion 2016-05-15

foreach ($currentVm in $allVms){
    #vms with the ImagePath tag are the ones we care about
    $imagePathValue = getTagValue $currentVm 'ImagePath'

    if($imagePathValue) {
        Write-Output ("##[command] Found Virtual Machine Running, will snap image of " + $currentVm.Name)

        $splitImagePath = $imagePathValue.Split('\')
        if($splitImagePath.Length -eq 1){
            #the image is directly in the GoldenImages folder. Just use the file name as the image name.
            $newimagename = $splitImagePath[0]
        }
        else {
            #this image is in a folder within GoldenImages. Name the image <FolderName>  <fileName> with <FolderName> set to the name of the folder that contains the image
            $segmentCount = $splitImagePath.Length
            $newimagename = $splitImagePath[$segmentCount - 2] + "  " + $splitImagePath[$segmentCount - 1]
        }

        #clean up some special characters in the image name and stamp it with todays date
        $newimagename = $newimagename.Replace(".json", "").Replace(".", "_")
        $newimagename = $newimagename +  " (" + (Get-Date -Format 'MMM d, yyyy').ToString() +  ")"

        $scriptFolder = Split-Path $Script:MyInvocation.MyCommand.Path
        $templatePath = Join-Path $scriptFolder "SnapImageFromVM.json"
        
        if($currentVm.Properties.OsType -eq "Windows") {
            $osType = "Windows"
        }
        else {
            $osType = "Linux"
        }

        $imageToCreate = @{
            ImageName = $newimagename
            ResourceGroupName = $ResourceGroupName
            DevTestLabName = $DevTestLabName
            templatePath = $templatePath
            vmResourceId = $currentVm.ResourceId
            imageDescription = $currentVm.Properties.Notes 
            imagePath = $imagePathValue
            osType = $osType
        }

        $existingImage = Get-AzureRmResource -ResourceName $DevTestLabName -ResourceGroupName $ResourceGroupName -ResourceType 'Microsoft.DevTestLab/labs/customImages' -ApiVersion '2016-05-15' | Where-Object -FilterScript {$_.Name -eq $newImageName}
        if($existingImage){
            Write-Output "Skipping the creation of $newImageName becuse it already exists"
        }
        else{
            Write-Output "Starting job to create image $newimagename"
            $jobs += Start-Job -Name $imageToCreate.ImageName -ScriptBlock $createImageBlock -ArgumentList $modulePath, $imageToCreate
        }
    }
}

if($jobs.Count -ne 0)
{
    try{
        $jobCount = $jobs.Count
        Write-Output "Waiting for $jobCount Image creation jobs to complete"
        foreach ($job in $jobs){
            Receive-Job $job -Wait | Write-Output
        }
    }
    finally{
        Remove-Job -Job $jobs
    }

    Write-Output "Completed snapping images!"
}
else 
{
    Write-Output "No images to create!"
}
