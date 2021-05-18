[CmdletBinding(DefaultParameterSetName = 'DtlVM')]
param
(
    [Parameter(Mandatory=$false, HelpMessage="Subscription for DevTest Lab")]
    [ValidateNotNullOrEmpty()]
    [string] $devTestLabSubscriptionId,
    
    [Parameter(Mandatory=$false, ParameterSetName='DtlVM', HelpMessage="DevTest Lab where the Virtual Machine exists")]
    [ValidateNotNullOrEmpty()]
    [string] $devTestLab,

    [Parameter(Mandatory=$false, ParameterSetName='ComputeVM', HelpMessage="The Resource group containing the Compute VM")]
    [ValidateNotNullOrEmpty()]
    [string] $resourceGroupName,

    [Parameter(Mandatory=$false, HelpMessage="Virtual Machine to use for pushing an image to Shared Image Gallery")]
    [ValidateNotNullOrEmpty()]
    [string] $virtualMachineName,

    [Parameter(Mandatory=$false, HelpMessage="Subscription for Shared Image Gallery")]
    [ValidateNotNullOrEmpty()]
    [string] $sharedImageGallerySubscriptionId,

    [Parameter(Mandatory=$false, HelpMessage="Shared Image Gallery name")]
    [ValidateNotNullOrEmpty()]
    [string] $sharedImageGalleryName,

    [Parameter(Mandatory=$false, HelpMessage="Image Definition name - can be new or existing")]
    [ValidateNotNullOrEmpty()]
    [string] $imageDefinitionName,

    [Parameter(Mandatory=$false, HelpMessage="Is the virtual machine specialized or generalized?")]
    [ValidateSet("Specialized", "Generalized")]
    [ValidateNotNullOrEmpty()]
    [string] $imageState,

    [Parameter(Mandatory=$false, HelpMessage="What HyperVGeneration to use (typically v1)?")]
    [ValidateSet("v1", "v2")]
    [ValidateNotNullOrEmpty()]
    [string] $imageDefinitionhyperVGeneration,

    [Parameter(Mandatory=$false, HelpMessage="Description for the Shared Image Gallery Image Definition")]
    [ValidateNotNullOrEmpty()]
    [string] $imageDefinitionDescription,

    [Parameter(Mandatory=$false, HelpMessage="Publisher for the Shared Image Gallery Image Definitoin")]
    [ValidateNotNullOrEmpty()]
    [string] $imageDefinitionPublisher,

    [Parameter(Mandatory=$false, HelpMessage="Offer for the Shared Image Gallery Image Definition")]
    [ValidateNotNullOrEmpty()]
    [string] $imageDefinitionOffer,

    [Parameter(Mandatory=$false, HelpMessage="SKU for the shared Image Gallery Image Definition")]
    [ValidateNotNullOrEmpty()]
    [string] $imageDefinitionSku,

    [Parameter(Mandatory=$false, HelpMessage="The new Image Version to use (1.0.2) format.  If left off, script will auto-increment the version")]
    [ValidateNotNullOrEmpty()]
    [string] $newImageVersion,

    [Parameter(Mandatory=$false, HelpMessage="Set the 'force' switch to avoid prompting the user to confirm the ImageState (specialized/generalized)")]
    [ValidateNotNullOrEmpty()]
    [switch] $force
)

# Lets stop the script for any errors
$ErrorActionPreference = "Stop"

function Get-ResourceWithPrompt {

    param (
        [Parameter(Mandatory=$true, HelpMessage="The type of resource that we're reconciling")]
        [ValidateNotNullOrEmpty()]
        [string] $resourceType,

        [Parameter(Mandatory=$true, HelpMessage="The prompt we use for the user if the resource name is blank")]
        [string] $prompt,

        [Parameter(Mandatory=$false, HelpMessage="The resource that we're searching for")]
        [string] $resourceValue,

        [Parameter(Mandatory=$false, HelpMessage="The Resource Group Name if we want to pick a specific resource")]
        [string] $resourceGroupName,

        [Parameter(Mandatory=$false, HelpMessage="The resource that we're searching for")]
        [switch] $allowCreateNew

    )

    # If the last character of resource value is a /, need to strip it
    if ($resourceValue.EndsWith('/')) {
        $resourceValue = $resourceValue -replace ".$"
    }

    # we also need to search if the resource value segments is more than 1 less than segments in resource type
    $isResourceSubtypeSearch = ($resourceValue.Split('/').Count -lt ($resourceType.Split('/').Count - 1))

    # if the user didn't specify the dev test lab, let's ask for one:
    if (-not $resourceValue -or $isResourceSubtypeSearch) {
        $index = 0
        if ($resourceType -ieq "azure/subscription") {
            $resources = Get-AzSubscription
        }
        elseif ($resourceType -ieq "azure/resourcegroup") {
            $resources = Get-AzResourceGroup | Sort-Object -Property ResourceGroupName
        }
        elseif ($resourceType -ieq "Microsoft.Compute/galleries/images") {
            $gallery = Get-AzGallery -Name $resourceValue
            $resources = Get-AzGalleryImageDefinition -ResourceGroupName $gallery.ResourceGroupName -GalleryName $gallery.Name 
        }
        elseif ($isResourceSubtypeSearch) {
            $resources = Get-AzResource -ResourceType $resourceType -Name "$resourceValue/*"
        }
        else {
            $resources = Get-AzResource -ResourceType $resourceType
        }

        if ($resourceGroupName) {
            $resources = $resources | Where-Object {$_.ResourceGroupName -ieq $resourceGroupName}
        }
        
        if (($resources | Measure-Object).Count -eq 0 -and -not $allowCreateNew) {
            Write-Error "No resources of type $resourceType available in subscription or you don't have access to them..."
        }

        if ($prompt) {
            Write-Host $prompt -ForegroundColor Green
        }
        else {
            Write-Host "Please choose a resource of type $resourceType :" -ForegroundColor Green
        }

        $resourceWithNumber = [Object[]] ($resources | ForEach-Object {
            Add-Member -InputObject $_ -MemberType NoteProperty -Name "Number" -Value "  $index"
            $index ++
            $_
        })

        if ($allowCreateNew) {
            $createNewItem = [PSCustomObject] @{
                Number = "  $(($resources | Measure-Object).Count)"
                Name = "Create a new resource..."
            }
            $resourceWithNumber += $createNewItem
        }

        if ($resourceType -ieq "azure/subscription") {
            $resourceWithNumber | Select Number, Name, Id | Format-Table | Out-String | Write-Host
        }
        elseif ($resourceType -ieq "azure/subscription") {
            $resourceWithNumber | Select Name, Location
        }
        elseif ($resourceType -ieq "Microsoft.Compute/galleries/images") {
            $resourceWithNumber | Select Number, Name, OsType, OsState | Format-Table | Out-String | Write-Host
        }
        else {
            $resourceWithNumber | Select Number, Name, ResourceGroupName, Location | Format-Table | Out-String | Write-Host
        } 

        $resourceNumber = Read-Host -Prompt "Resource Number"
        
        if ($allowCreateNew -and $resourceNumber -eq ($resources | Measure-Object).Count) {
            $resource = "CreateNew"
        }
        else {
            $resource = $resources[$resourceNumber]
        }

        if (-not $resource) {
            Write-Error "Invalid choice for $resourceType .."
        }
    }

    # If we didn't get the object from the user, let's try to get it by name
    if (-not $resource) {
        if ($resourceType -ieq "azure/subscription") {
            $resource = Get-AzSubscription -SubscriptionId $resourceValue
        }
        elseif ($resourceType -ieq "azure/resourcegroup") {
            $resource = Get-AzResourceGroup -name $resourceValue
        }
        else {
            $resource = Get-AzResource -ResourceType $resourceType -Name $resourceValue
        }
    
        # guard against accidently pulling resources via a blank or wildcard - must have 1 and only 1 resource
        if (($resource | Measure-Object).Count -ne 1) {
            Write-Error "Unable to find $resourceType with the name '$resourceValue'"
        }
    }

    # return the resource
    return $resource
}

$subscription = Get-ResourceWithPrompt -resourceType "azure/subscription" -resourceValue $devTestLabSubscriptionId -prompt "Please choose the subscription for the DevTest Lab containing the Virtual Machine to use:"

# select the subscription if not the current one
if ((Get-AzContext).Subscription.Id -ine $subscription.Id) {
    Select-AzSubscription -Subscription $subscription.Id
}

# User didn't specify either DevTest Lab or Resource Group Name, need to ask them
if (-not $devTestLab -and -not $resourceGroupName) {
    $isDTL = Read-Host -Prompt "Is this a DTL VM?  (Yes/No)"
}

# We need to reconcile all the parameters...  If we can't find any resources, we'll get an error and the script will stop

if ($isDTL -ieq "yes" -or $devTestLab) {
    $lab = Get-ResourceWithPrompt -resourceType "Microsoft.DevTestLab/Labs" -resourceValue $devTestLab -prompt "Please choose the DevTest Lab that contains the Virtual Machine to use:"
    $virtualMachineSlim = Get-ResourceWithPrompt -resourceType "Microsoft.DevTestLab/Labs/VirtualMachines" -resourceValue ($lab.Name + "/" + $virtualMachineName) -prompt "Please choose the source Virtual Machine:"

    # This second call will fill out the properties
    $virtualMachine = Get-AzResource -ResourceId $virtualMachineSlim.Id
    # Get the compute info in case we need it later
    $computeObj = Get-AzResource -ResourceId $virtualMachine.Properties.computeId

}
else {
    $vmRg = Get-ResourceWithPrompt -resourceType "azure/resourcegroup" -resourceValue $resourceGroupName -prompt "Please choose the Resource Group that contains the Virtual Machine to use:"
    $virtualMachineSlim = Get-ResourceWithPrompt -resourceType "Microsoft.Compute/virtualMachines" -resourceGroupName $vmRg.ResourceGroupName -resourceValue $virtualMachineName -prompt "Please choose the source Virtual Machine:"
    # Get the compute info in case we need it later
    $computeObj = Get-AzResource -ResourceId $virtualMachineSlim.Id
}

$subscriptionSIG = Get-ResourceWithPrompt -resourceType "azure/subscription" -resourceValue $sharedImageGallerySubscriptionId -prompt "Please choose the subscription containing the destination Shared Image Gallery"

# select the subscription if not the current one
if ((Get-AzContext).Subscription.Id -ine $subscriptionSIG.Id) {
    Select-AzSubscription -Subscription $subscriptionSIG.Id
}

$sharedImageGallery = Get-ResourceWithPrompt -resourceType "Microsoft.Compute/galleries" -resourceValue $sharedImageGalleryName -prompt "Please choose the destination Shared Image Gallery:"
$imageDefinition = Get-ResourceWithPrompt -resourceType "Microsoft.Compute/galleries/images" -resourceValue ($sharedImageGallery.Name + "/" + $imageDefinitionName) -prompt "Please choose the Image Definition in the Shared Image Gallery:" -allowCreateNew

# If the user picked "Create new..." than we should validate the parameters and create a new image definition
if ($imageDefinition -ieq "CreateNew") {
    $imageDefinitionName = Read-Host -Prompt "Please enter a new Image Definition Name (letters, numbers, hyphens, underscores/periods in the middle)"
    if (-not $imageState) {$imageState = Read-Host -Prompt "Please enter an Image State (Specialized or Generalized)"}
    if (-not $imageDefinitionPublisher) {$imageDefinitionPublisher = Read-Host -Prompt "Please enter a Publisher for the image"}
    if (-not $imageDefinitionOffer) {$imageDefinitionOffer = Read-Host -Prompt "Please enter the Offer for the image"}
    if (-not $imageDefinitionSku) {$imageDefinitionSku = Read-Host -Prompt "Please enter the SKU for the image"}
    if (-not $imageDefinitionhyperVGeneration) {$imageDefinitionhyperVGeneration = Read-Host -Prompt "Please enter the HyperVGeneration to use (v1 or v2)"}

    $imageDefinition = New-AzGalleryImageDefinition -ResourceGroupName $sharedImageGallery.ResourceGroupName `
                                                    -GalleryName $sharedImageGallery.Name `
                                                    -Name $imageDefinitionName `
                                                    -OsType $computeObj.Properties.storageProfile.osDisk.osType `
                                                    -HyperVGeneration $imageDefinitionhyperVGeneration `
                                                    -OsState $imageState `
                                                    -Publisher $imageDefinitionPublisher `
                                                    -Offer $imageDefinitionOffer `
                                                    -Sku $imageDefinitionSku `
                                                    -Location $sharedImageGallery.Location
}
else {
    # If the user picked an existing image definition - we need to make sure the other parameters aren't set
    if ($imageState) {Write-Error "Unable to proceed, if an existing Image Definition is selected, should not specify the 'imageState' parameter"}
    if ($imageDefinitionPublisher) {Write-Error "Unable to proceed, if an existing Image Definition is selected, should not specify the 'imageDefinitionPublisher' parameter"}
    if ($imageDefinitionOffer) {Write-Error "Unable to proceed, if an existing Image Definition is selected, should not specify the 'imageDefinitionOffer' parameter"}
    if ($imageDefinitionSku) {Write-Error "Unable to proceed, if an existing Image Definition is selected, should not specify the 'imageDefinitionSku' parameter"}
    if ($imageDefinitionhyperVGeneration) {Write-Error "Unable to proceed, if an existing Image Definition is selected, should not specify the 'imageDefinitionhyperVGeneration' parameter"}
}

# Ask the user if they're sure on the image state
if (-not $force) {
    if ($imageDefinition.OsState -ieq "Specialized") {
        Write-Host "The Virtual Machine OS Disk will be saved to Shared Image Gallery.  This operation does not alter the disk, but could cause a reboot of the virtual machine.  Type 'yes' if this is OK." -ForegroundColor Yellow
    }
    else {
        Write-Host "Please confirm that the Virtual Machine has already been sysprep'd/deprovisioned (Generalized) before proceeding.  Type 'yes' if the VM has already been generalized." -ForegroundColor Yellow
    }
    $result = Read-Host
}

if ($result -ieq "yes") {

    # At this point, we know the VM, we know the SIG & Image Definition. Let's create a new image version - first get the latest
    $latestVersion = Get-AzGalleryImageVersion -ResourceGroupName $sharedImageGallery.ResourceGroupName `
                                               -GalleryName $sharedImageGallery.Name `
                                               -GalleryImageDefinitionName $imageDefinition.Name `
                                               | ForEach-Object { New-Object System.Version ($_.Name) } `
                                               | Sort-Object -Descending | Select -First 1

    # If the user specified a image version, make sure it's greater than existing
    if ($newImageVersion) {
        $newImageVersionObj = New-Object System.Version ($newImageVersion)
        if ($latestVersion -and $newImageVersionObj -le $latestVersion) {
            Write-Error "Version specified in 'newImageVersion' parameter is equal or less than the latest version in the shared image gallery, cannot continue..."
        }
    }
    else {
        # User didn't specify existing, let's guess one
        if ($latestVersion) {
            $newImageVersion = "$($latestVersion.Major).$($latestVersion.Minor).$($latestVersion.Build + 1)"
        }
        else {
            $newImageVersion = "1.0.0"
        }
    }

    Write-Host "Starting to create the new image version, this takes some time (for copying/replicating)...  You can check the current replication status for the Image Version in the Azure Portal." -ForegroundColor Green

    if ($imageDefinition.OsState -ieq "Specialized") {

        # Can point directly at the VM for specialized image
        $imageVersion = New-AzGalleryImageVersion -ResourceGroupName $sharedImageGallery.ResourceGroupName `
                                                  -GalleryName $sharedImageGallery.Name `
                                                  -GalleryImageDefinitionName $imageDefinition.Name `
                                                  -SourceImageId $computeObj.Id `
                                                  -Name $newImageVersion `
                                                  -Location $computeObj.Location

    }
    else {

        # For generalized images, we have to switch back to the lab subscription to get more info
        if ((Get-AzContext).Subscription.Id -ine $subscription.Id) {
            Select-AzSubscription -Subscription $subscription.Id
        }

        # Get the OS disk to construct the OS Profile
        $osDisk = Get-AzDisk -ResourceGroupName $computeObj.Properties.storageProfile.osDisk.managedDisk.id.Split('/')[4] -DiskName $computeObj.Properties.storageProfile.osDisk.managedDisk.id.Split('/')[8]
        $osDiskProfile = New-Object Microsoft.Azure.Management.Compute.Models.GalleryOSDiskImage($osDisk.DiskSizeGB, $computeObj.Properties.storageProfile.osDisk.caching, $computeObj.Properties.storageProfile.osDisk.managedDisk.id)

        $dataDiskProfiles = $computeObj.Properties.storageProfile.dataDisks | ForEach-Object {
            $dataDisk = Get-AzDisk -ResourceGroupName $_.managedDisk.id.Split('/')[4] -DiskName $_.managedDisk.id.Split('/')[8]
            New-Object Microsoft.Azure.Management.Compute.Models.GalleryDataDiskImage($_.lun,$dataDisk.DiskSizeGB, $_.caching, $_.managedDisk.id)
        }

        # switch back to SIG subscription so we can submit the request for a new gallery image
        if ((Get-AzContext).Subscription.Id -ine $subscriptionSIG.Id) {
            Select-AzSubscription -Subscription $subscriptionSIG.Id
        }

        # If Generalized, need to point at the OS Disk and Data Disks
        $imageVersion = New-AzGalleryImageVersion -ResourceGroupName $sharedImageGallery.ResourceGroupName `
                                                  -GalleryName $sharedImageGallery.Name `
                                                  -GalleryImageDefinitionName $imageDefinition.Name `
                                                  -OSDiskImage $osDiskProfile `
                                                  -DataDiskImage $dataDiskProfiles `
                                                  -Name $newImageVersion `
                                                  -Location $computeObj.Location

    }


    if ($imageVersion) {
        $imageVersion | Out-String | Write-Host
        Write-Host "Completed script Ssuccessfully!" -ForegroundColor Green
    }
    else {
        Write-Host "It appears the script didn't complete successfully, unable to create the image version..." -FOregroundColor Yellow
    }
}
else {
    Write-Host "Aborting script..." -ForegroundColor Yellow
}
