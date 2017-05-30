param
(
    [Parameter(Mandatory=$true, HelpMessage="The name of the DevTest Lab resource group")]
    [string] $ResourceGroupName,

    [Parameter(Mandatory=$true, HelpMessage="The name of the DevTest Lab to clean up")]
    [string] $DevTestLabName
)
$modulePath = Join-Path (Split-Path ($Script:MyInvocation.MyCommand.Path)) "DistributionHelpers.psm1"
Import-Module $modulePath
SaveProfile

$allVms = Find-AzureRmResource -ResourceType "Microsoft.DevTestLab/labs/virtualMachines" -ResourceNameContains $DevTestLabName
$jobs = @()

$deleteVmBlock = {
    Param($modulePath, $vmName, $resourceId)
    Import-Module $modulePath
    LoadProfile
    Write-Output "##[section]Deleting VM: $vmName"
    Remove-AzureRmResource -ResourceId $resourceId -ApiVersion 2017-04-26-preview -Force
    Write-Output "##[section]Completed deleting $vmName"
}

# Script block for deleting images
$deleteImageBlock = {
    Param($modulePath, $imageResourceName, $resourceGroupName)
    Import-Module $modulePath
    LoadProfile
    deleteImage $resourceGroupName $imageResourceName
}

# Iterate over all the VMs and delete any that we created
foreach ($currentVm in $allVms){
    $ignoreTagName = 'FactoryIgnore'
    $factoryIgnoreTag = getTagValue $currentVm $ignoreTagName
    $imagePathTag = getTagValue $currentVm 'ImagePath'
    $vmName = $currentVm.ResourceName
    $provisioningState = (Get-AzureRmResource -ResourceId $currentVm.ResourceId).Properties.ProvisioningState

    if(($provisioningState -ne "Succeeded") -and ($provisioningState -ne "Creating")){
        #these VMs failed to provision. log an error to make sure they get attention from the lab owner then delete them
        Write-Error "$vmName failed to provision properly. Deleting it from Factory"
        $jobs += Start-Job -ScriptBlock $deleteVmBlock -ArgumentList $modulePath, $vmName, $currentVm.ResourceId
    }
    elseif(!$factoryIgnoreTag -and !$imagePathTag){
        #if a VM has neither the ignore or imagePath then log an error
        Write-Error "VM named $vmName is not recognized in the lab. Please add the $ignoreTagName tag to the VM if it belongs here"
    }
    elseif($factoryIgnoreTag){
        Write-Output "Ignoring VM $vmName because it has the $ignoreTagName tag"
    }
    else {
        Write-Output "Starting job to delete VM $vmName"
        $jobs += Start-Job -ScriptBlock $deleteVmBlock -ArgumentList $modulePath, $vmName, $currentVm.ResourceId
    }
}

# Find any custom images that failed to provision and delete those
$bustedLabCustomImages = Get-AzureRmResource -ResourceName $DevTestLabName -ResourceGroupName $ResourceGroupName -ResourceType 'Microsoft.DevTestLab/labs/customImages' -ApiVersion '2017-04-26-preview' | Where-Object {($_.Properties.ProvisioningState -ne "Succeeded") -and ($_.Properties.ProvisioningState -ne "Creating")}

# Delete the custom images we found in the search above
foreach ($imageToDelete in $bustedLabCustomImages) {
    $jobs += Start-Job -Name $imageToDelete.ResourceName -ScriptBlock $deleteImageBlock -ArgumentList $modulePath, $imageToDelete.ResourceName, $imageToDelete.ResourceGroupName
}

if($jobs.Count -ne 0)
{
    try{
        Write-Output "Waiting for VM Delete jobs to complete"
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
    Write-Output "No VMs to delete"
}

Write-Output "Cleanup complete"