<##################################################################################################

    Usage Example
    =============

    Login-AzureRmAccount
    Import-Module .\Cmdlets.DevTestLab.ps1
    Get-AzureRmDtlLab   


    Help / Documentation
    ====================
    - To view a cmdlet's help description: Get-help "cmdlet-name" -Detailed
    - To view a cmdlet's usage example: Get-help "cmdlet-name" -Examples


    Pre-Requisites
    ==============
    - Please ensure that the powershell execution policy is set to unrestricted or bypass.
    - Please ensure that the latest version of Azure Powershell in installed on the machine.


    Known Issues
    ============
    - The following regression in the Azure PS cmdlets impacts us currently. 
      - https://github.com/Azure/azure-powershell/issues/1259

##################################################################################################>

#
# Configurations
#

# Resource types exposed by the DevTestLab provider.
$LabResourceType = "microsoft.devtestlab/labs"
$VirtualMachineResourceType = "microsoft.devtestlab/labs/virtualmachines"
$CustomImageResourceType = "microsoft.devtestlab/labs/customimages"
$GalleryImageResourceType = "microsoft.devtestlab/labs/galleryimages"
$ArtifactSourceResourceType = "microsoft.devtestlab/labs/artifactsources"
$ArtifactResourceType = "microsoft.devtestlab/labs/artifactsources/artifacts"

# Other resource types
$StorageAccountResourceType = "microsoft.storage/storageAccounts"

# The API version required to query DTL resources
$RequiredApiVersion = "2015-05-21-preview"

# Paths to Azure RM templates for the DevTest Lab provider. 
$ARMTemplate_CreateLab = ".\101-dtl-create-lab-azuredeploy.json"
$ARMTemplate_CreateVM_BuiltinUsr = ".\101-dtl-create-vm-builtin-user-azuredeploy.json"
$ARMTemplate_CreateVM_UsrPwd_CustomImage = ".\101-dtl-create-vm-username-pwd-customimage-azuredeploy.json"
$ARMTemplate_CreateVM_UsrPwd_GalleryImage = ".\101-dtl-create-vm-username-pwd-galleryimage-azuredeploy.json"
$ARMTemplate_CreateVM_UsrSSH_CustomImage = ".\101-dtl-create-vm-username-ssh-customimage-azuredeploy.json"
$ARMTemplate_CreateVM_UsrSSH_GalleryImage = ".\101-dtl-create-vm-username-ssh-galleryimage-azuredeploy.json"
$ARMTemplate_CreateLab_WithPolicies = ".\201-dtl-create-lab-with-policies-azuredeploy.json"
$ARMTemplate_CreateCustomImage_FromImage = ".\201-dtl-create-customimage-from-azure-image-azuredeploy.json"
$ARMTemplate_CreateCustomImage_FromVhd = ".\201-dtl-create-customimage-from-vhd-azuredeploy.json"
$ARMTemplate_CreateCustomImage_FromWindowsVM = ".\201-dtl-create-customimage-from-windows-vm-azuredeploy.json"
$ARMTemplate_CreateCustomImage_FromLinuxVM = ".\201-dtl-create-customimage-from-linux-vm-azuredeploy.json"

##################################################################################################

#
# Private helper methods
#

function GetLabFromNestedResource_Private
{
    Param(
        [ValidateNotNull()]
        # An existing Lab nested resource Id
        $NestedResourceId
    )
    $array = $NestedResourceId.split("/")
    $parts = $array[0..($array.Count - 3)]
    $labId = [string]::Join("/",$parts)

    $lab = Get-AzureRmResource -ResourceId $labId

    if ($null -eq $lab)
    {
        throw $("Unable to detect lab for resource '" + $NestedResourceId + "'")
    }

    return $lab
}

function GetLabFromVM_Private
{
    Param(
        [ValidateNotNull()]
        # An existing VM (please use the Get-AzureRmDtlVirtualMachine cmdlet to get this VM object).
        $VM
    )

    $lab = GetLabFromNestedResource_Private -NestedResource $VM.ResourceId

    if ($null -eq $lab)
    {
        throw $("Unable to detect lab for VM '" + $VM.ResourceName + "'")
    }

    return $lab
}

function GetLabFromVhd_Private
{
    Param(
        [ValidateNotNull()]
        # An existing Vhd (please use the Get-AzureRmDtlVhd cmdlet to get this vhd object).
        $Vhd
    )

    if (($null -eq $Vhd) -or ($null -eq $Vhd.Context) -or ($null -eq $Vhd.Context.StorageAccountName))
    {
        throw $("Unable to determine the storage account name for the vhd '" + $Vhd.Name + "'.")
    }

    $vhdStorageAccount = Get-AzureRmResource | Where-Object {
        $_.ResourceType -eq $StorageAccountResourceType -and 
        $_.ResourceName -eq $Vhd.Context.StorageAccountName
    }

    if ($null -eq $vhdStorageAccount)
    {
        throw $("Unable to extract the storage account '" + $Vhd.Context.StorageAccountName + "'")
    }

    # Note: The -ErrorAction 'SilentlyContinue' ensures that we suppress irrelevant
    # errors originating while expanding properties (especially in internal test and
    # pre-production subscriptions).
    $lab = Get-AzureRmResource -ExpandProperties -ErrorAction "SilentlyContinue" | Where-Object {
        $_.ResourceType -eq $LabResourceType -and
        $_.Properties.DefaultStorageAccount -eq $vhdStorageAccount.ResourceId
    }

    if ($null -eq $lab)
    {
        throw $("Unable to detect lab for Vhd '" + $Vhd.Name + "'")
    }

    return $lab
}

function GetResourceWithProperties_Private
{
    Param(
        [ValidateNotNull()]
        # ResourceId of an existing Azure RM resource.
        $Resource
    )

    if ($null -eq $Resource.Properties)
    {
        Get-AzureRmResource -ExpandProperties -ResourceId $Resource.ResourceId -ApiVersion $RequiredApiVersion
    }
    else
    {
        return $Resource
    }
}

function CreateNewResourceGroup_Private
{
    Param(
        [ValidateNotNullOrEmpty()]
        [string]
        # Seed/Prefix for the new resource group name to be generated.
        $ResourceGroupSeedPrefixName,

        [ValidateNotNullOrEmpty()]
        [string]
        # Location where the new resource group will be generated.
        $Location
    )

    # Using the seed/prefix, we'll generate a unique random name for the resource group.
    # We'll then check if there is an existing resource group with the same name.
    do
    {
        # NOTE: Unfortunately the Get-AzureRmResourceGroup cmdlet throws a terminating error 
        # if the specified resource group name does not exist. So we'll use a try/catch block.
        try
        {
            $randomRGName = $($ResourceGroupSeedPrefixName + (Get-Random).ToString())
            $randomRG = Get-AzureRmResourceGroup -Name $randomRGName -ErrorAction "SilentlyContinue"
        }
        catch [ArgumentException]
        {
            $randomRG = $null
        }
    }
    until ($null -eq $randomRG)

    return (New-AzureRmResourceGroup -Name $randomRGName -Location $Location)
}

##################################################################################################

function Get-AzureRmDtlLab
{
    <#
        .SYNOPSIS
        Gets labs under the current subscription.

        .DESCRIPTION
        The Get-AzureRmDtlLab cmdlet does the following: 
        - Gets a specific lab, if the -LabId parameter is specified.
        - Gets all labs with matching name, if the -LabName parameter is specified.
        - Gets all labs with matching name within a resource group, if the -LabName and -LabResourceGroupName parameters are specified.
        - Gets all labs in a resource group, if the -LabResourceGroupName parameter is specified.
        - Gets all labs in a location, if the -LabLocation parameter is specified.
        - Gets all labs within current subscription, if no parameters are specified. 

        .EXAMPLE
        Get-AzureRmDtlLab -LabId "/subscriptions/xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx/resourceGroups/MyLabRG/providers/Microsoft.DevTestLab/labs/MyLab"
        Gets a specific lab, identified by the specified resource-id.

        .EXAMPLE
        Get-AzureRmDtlLab -LabName "MyLab"
        Gets all labs with the name "MyLab".

        .EXAMPLE
        Get-AzureRmDtlLab -LabName "MyLab" -LabResourceGroupName "MyLabRG"
        Gets all labs with the name "MyLab" within the resource group "MyLabRG".

        .EXAMPLE
        Get-AzureRmDtlLab -LabResourceGroupName "MyLabRG"
        Gets all labs in the "MyLabRG" resource group.

        .EXAMPLE
        Get-AzureRmDtlLab -LabLocation "westus"
        Gets all labs in the "westus" location.

        .EXAMPLE
        Get-AzureRmDtlLab
        Gets all labs within current subscription (use the Select-AzureRmSubscription cmdlet to change the current subscription).

        .INPUTS
        None. Currently you cannot pipe objects to this cmdlet (this will be fixed in a future version).  
    #>
    [CmdletBinding(DefaultParameterSetName="ListAll")]
    Param(
        [Parameter(Mandatory=$true, ParameterSetName="ListByLabId")] 
        [ValidateNotNullOrEmpty()]
        [string]
        # The ResourceId of the lab (e.g. "/subscriptions/xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx/resourceGroups/MyLabRG/providers/Microsoft.DevTestLab/labs/MyLab").
        $LabId,

        [Parameter(Mandatory=$true, ParameterSetName="ListByLabName")] 
        [ValidateNotNullOrEmpty()]
        [string]
        # The name of the lab.
        $LabName,

        [Parameter(Mandatory=$false, ParameterSetName="ListByLabId")] 
        [Parameter(Mandatory=$false, ParameterSetName="ListByLabName")] 
        [Parameter(Mandatory=$false, ParameterSetName="ListAll")] 
        [switch]
        # Optional. If specified, fetches the properties of the lab(s).
        $ShowProperties
    )

    PROCESS
    {
        Write-Verbose $("Processing cmdlet '" + $PSCmdlet.MyInvocation.InvocationName + "', ParameterSet = '" + $PSCmdlet.ParameterSetName + "'")

        $output = $null

        switch($PSCmdlet.ParameterSetName)
        {
            "ListByLabId"
            {
                $output = Get-AzureRmResource | Where-Object { 
                    $_.ResourceType -eq $LabResourceType -and 
                    $_.ResourceId -eq $LabId 
                }
            }
                    
            "ListByLabName"
            {
                $output = Get-AzureRmResource | Where-Object { 
                    $_.ResourceType -eq $LabResourceType -and 
                    $_.ResourceName -eq $LabName 
                }     
            }

            "ListAll" 
            {
                $output = Get-AzureRmResource | Where-Object { 
                    $_.ResourceType -eq $LabResourceType 
                }
            }
        }

        # now let us display the output
        if ($PSBoundParameters.ContainsKey("ShowProperties"))
        {
            foreach ($item in $output)
            {
                GetResourceWithProperties_Private -Resource $item | Write-Output
            }
        }
        else
        {
            $output | Write-Output
        }
    }
}

##################################################################################################

function Get-AzureRmDtlCustomImage
{
    <#
        .SYNOPSIS
        Gets custom images from a specified lab.

        .DESCRIPTION
        The Get-AzureRmDtlCustomImage cmdlet does the following: 
        - Gets all custom images from a lab, if the -Lab parameter is specified.
        - Gets all custom images with matching name from a lab, if the -CustomImageName and -Lab parameters are specified.
        - Gets a specific custom image, if the -CustomImageId parameter is specified.

        .EXAMPLE
        $lab = $null

        $lab = Get-AzureRmDtlLab -LabName "MyLab1"
        Get-AzureRmDtlCustomImage -Lab $lab

        Gets all custom images from the lab "MyLab1".

        .EXAMPLE
        $lab = $null

        $lab = Get-AzureRmDtlLab -LabName "MyLab1"
        Get-AzureRmDtlCustomImage -CustomImageName "MyCustomImage1" -Lab $lab

        Gets all custom images with the name "MyCustomImage1" from the lab "MyLab1".

        .EXAMPLE
        Get-AzureRmDtlCustomImage -CustomImageId "/subscriptions/xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx/resourceGroups/MyLabRG/providers/Microsoft.DevTestLab/labs/MyLab1/customimages/MyCustomImage1"
        Gets a specific custom image, identified by the specified resource-id.

        .INPUTS
        None. Currently you cannot pipe objects to this cmdlet (this will be fixed in a future version).  
    #>
    [CmdletBinding(DefaultParameterSetName="ListByCustomImageName")]
    Param(
        [Parameter(Mandatory=$true, ParameterSetName="ListByCustomImageId")] 
        [ValidateNotNullOrEmpty()]
        [string]
        # The ResourceId of the custom image (e.g. "/subscriptions/xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx/resourceGroups/MyLabRG/providers/Microsoft.DevTestLab/labs/MyLab1/customimages/MyCustomImage1").
        $CustomImageId,

        [Parameter(Mandatory=$false, ParameterSetName="ListByCustomImageName")] 
        [ValidateNotNullOrEmpty()]
        [string]
        # The name of the custom image 
        $CustomImageName,

        [Parameter(Mandatory=$true, ParameterSetName="ListByCustomImageName")] 
        [ValidateNotNull()]
        # An existing lab (please use the Get-AzureRmDtlLab cmdlet to get this lab object).
        $Lab,

        [Parameter(Mandatory=$false, ParameterSetName="ListByCustomImageId")] 
        [Parameter(Mandatory=$false, ParameterSetName="ListByCustomImageName")] 
        [switch]
        # Optional. If specified, fetches the properties of the custom image(s).
        $ShowProperties
    )

    PROCESS
    {
        Write-Verbose $("Processing cmdlet '" + $PSCmdlet.MyInvocation.InvocationName + "', ParameterSet = '" + $PSCmdlet.ParameterSetName + "'")

        $output = $null

        switch ($PSCmdlet.ParameterSetName)
        {
            "ListByCustomImageId"
            {
                $output = Get-AzureRmResource -ResourceId $CustomImageId -ApiVersion $RequiredApiVersion
            }

            "ListByCustomImageName"
            {
                $output = Get-AzureRmResource -ResourceName $Lab.ResourceName -ResourceGroupName $Lab.ResourceGroupName -ResourceType $CustomImageResourceType -ApiVersion $RequiredApiVersion

                if ($PSBoundParameters.ContainsKey("CustomImageName"))
                {
                    $output = $output | Where-Object {
                        $_.Name -eq $CustomImageName 
                    }
                }
            }
        }

        # now let us display the output
        if ($PSBoundParameters.ContainsKey("ShowProperties"))
        {
            foreach ($item in $output)
            {
                GetResourceWithProperties_Private -Resource $item | Write-Output
            }
        }
        else
        {
            $output | Write-Output
        }
    }
}

##################################################################################################

function Get-AzureRmDtlGalleryImage
{
    <#
        .SYNOPSIS
        Gets gallery images from a specified lab.

        .DESCRIPTION
        The Get-AzureRmDtlGalleryImage cmdlet does the following: 
        - Gets all gallery images from a lab, if the -Lab parameter is specified.
        - Gets all gallery images with matching name from a lab, if the -GalleryImageName and -Lab parameters are specified.
        - Gets a specific gallery image, if the -GalleryImageId parameter is specified.

        .EXAMPLE
        $lab = $null

        $lab = Get-AzureRmDtlLab -LabName "MyLab1"
        Get-AzureRmDtlGalleryImage -Lab $lab

        Gets all gallery images from the lab "MyLab1".

        .EXAMPLE
        $lab = $null

        $lab = Get-AzureRmDtlLab -LabName "MyLab1"
        Get-AzureRmDtlGalleryImage -GalleryImageName "MyGalleryImage1" -Lab $lab

        Gets all gallery images with the name "MyGalleryImage1" from the lab "MyLab1".

        .EXAMPLE
        Get-AzureRmDtlGalleryImage -GalleryImageId "/subscriptions/xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx/resourceGroups/MyLabRG/providers/Microsoft.DevTestLab/labs/MyLab1/galleryimages/MyGalleryImage1"
        Gets a specific gallery image, identified by the specified resource-id.

        .INPUTS
        None. Currently you cannot pipe objects to this cmdlet (this will be fixed in a future version).  
    #>
    [CmdletBinding(DefaultParameterSetName="ListByGalleryImageName")]
    Param(
        [Parameter(Mandatory=$true, ParameterSetName="ListByGalleryImageId")] 
        [ValidateNotNullOrEmpty()]
        [string]
        # The ResourceId of the gallery image (e.g. "/subscriptions/xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx/resourceGroups/MyLabRG/providers/Microsoft.DevTestLab/labs/MyLab1/galleryimages/MyGalleryImage1").
        $GalleryImageId,

        [Parameter(Mandatory=$false, ParameterSetName="ListByGalleryImageName")] 
        [ValidateNotNullOrEmpty()]
        [string]
        # The name of the gallery image 
        $GalleryImageName,

        [Parameter(Mandatory=$true, ParameterSetName="ListByGalleryImageName")] 
        [ValidateNotNull()]
        # An existing lab (please use the Get-AzureRmDtlLab cmdlet to get this lab object).
        $Lab,

        [Parameter(Mandatory=$false, ParameterSetName="ListByGalleryImageId")] 
        [Parameter(Mandatory=$false, ParameterSetName="ListByGalleryImageName")] 
        [switch]
        # Optional. If specified, fetches the properties of the gallery image(s).
        $ShowProperties
    )

    PROCESS
    {
        Write-Verbose $("Processing cmdlet '" + $PSCmdlet.MyInvocation.InvocationName + "', ParameterSet = '" + $PSCmdlet.ParameterSetName + "'")

        $output = $null

        switch ($PSCmdlet.ParameterSetName)
        {
            "ListByGalleryImageId"
            {
                $output = Get-AzureRmResource -ResourceId $GalleryImageId -ApiVersion $RequiredApiVersion
            }

            "ListByGalleryImageName"
            {
                $output = Get-AzureRmResource -ResourceName $Lab.ResourceName -ResourceGroupName $Lab.ResourceGroupName -ResourceType $GalleryImageResourceType -ApiVersion $RequiredApiVersion

                if ($PSBoundParameters.ContainsKey("GalleryImageName"))
                {
                    $output = $output | Where-Object {
                        $_.Name -eq $GalleryImageName 
                    }
                }
            }
        }

        # now let us display the output
        if ($PSBoundParameters.ContainsKey("ShowProperties"))
        {
            foreach ($item in $output)
            {
                GetResourceWithProperties_Private -Resource $item | Write-Output
            }
        }
        else
        {
            $output | Write-Output
        }
    }
}

##################################################################################################

function Get-AzureRmDtlArtifact
{
    <#
        .SYNOPSIS
        Gets artifacts from a specified lab.

        .DESCRIPTION
        The Get-AzureRmDtlArtifact cmdlet does the following: 
        - Gets all artifacts from a lab, if the -Lab parameter is specified.
        - Gets all artifacts from a specific artifact repo of a lab, if the -ArtifactSourceName and -Lab parameters are specified.
        - Gets all artifacts with matching name from a lab, if the -ArtifactName and -Lab parameters are specified.
        - Gets all artifacts with matching name from a specific artifact repo of a lab, if the -ArtifactName, -ArtifactSourceName and -Lab parameters are specified.
        - Gets a specific artifact, if the -ArtifactId parameter is specified.

        .EXAMPLE
        $lab = $null

        $lab = Get-AzureRmDtlLab -LabName "MyLab1"
        Get-AzureRmDtlArtifact -Lab $lab

        Gets all artifacts from the lab "MyLab1".

        .EXAMPLE
        $lab = $null

        $lab = Get-AzureRmDtlLab -LabName "MyLab1"
        Get-AzureRmDtlArtifact -Lab $lab -ArtifactSource "MyArtifactRepo1"

        Gets all artifacts from the artifact repo "MyArtifactRepo1" of the lab "MyLab1".

        .EXAMPLE
        $lab = $null

        $lab = Get-AzureRmDtlLab -LabName "MyLab1"
        Get-AzureRmDtlArtifact -ArtifactName "MyArtifact1" -Lab $lab

        Gets all artifacts with the name "MyArtifact1" from the lab "MyLab1".

        .EXAMPLE
        $lab = $null

        $lab = Get-AzureRmDtlLab -LabName "MyLab1"
        Get-AzureRmDtlArtifact -ArtifactName "MyArtifact1" -ArtifactSource "MyArtifactRepo1" -Lab $lab

        Gets all artifacts with the name "MyArtifact1" from the artifact repo "MyArtifactRepo1" of the lab "MyLab1".

        .EXAMPLE
        Get-AzureRmDtlArtifact -ArtifactId "/subscriptions/xxxxxxxx-xxxx-xxxx/resourceGroups/MyLabRG/providers/Microsoft.DevTestLab/labs/MyLab1/artifactSources/MyArtifactRepo1/artifacts/MyArtifact1"
        Gets a specific artifact, identified by the specified resource-id.

        .INPUTS
        None. Currently you cannot pipe objects to this cmdlet (this will be fixed in a future version).  
    #>
    [CmdletBinding(DefaultParameterSetName="ListByArtifactName")]
    Param(
        [Parameter(Mandatory=$true, ParameterSetName="ListByArtifactId")] 
        [ValidateNotNullOrEmpty()]
        [string]
        # The ResourceId of the artifact (e.g. "/subscriptions/xxxxxxxx-xxxx-xxxx/resourceGroups/MyLabRG/providers/Microsoft.DevTestLab/labs/MyLab1/artifactSources/MyArtifactRepo1/artifacts/MyArtifact1").
        $ArtifactId,

        [Parameter(Mandatory=$false, ParameterSetName="ListByArtifactName")] 
        [ValidateNotNullOrEmpty()]
        [string]
        # The name of the artifact
        $ArtifactName,

        [Parameter(Mandatory=$false, ParameterSetName="ListByArtifactName")] 
        [ValidateNotNullOrEmpty()]
        [string]
        # The name of the artifact source
        $ArtifactSourceName,

        [Parameter(Mandatory=$true, ParameterSetName="ListByArtifactName")] 
        [ValidateNotNull()]
        # An existing lab (please use the Get-AzureRmDtlLab cmdlet to get this lab object).
        $Lab,

        [Parameter(Mandatory=$false, ParameterSetName="ListByArtifactId")] 
        [Parameter(Mandatory=$false, ParameterSetName="ListByArtifactName")] 
        [switch]
        # Optional. If specified, fetches the properties of the artifact(s).
        $ShowProperties
    )

    PROCESS
    {
        Write-Verbose $("Processing cmdlet '" + $PSCmdlet.MyInvocation.InvocationName + "', ParameterSet = '" + $PSCmdlet.ParameterSetName + "'")

        $output = $null

        switch ($PSCmdlet.ParameterSetName)
        {
            "ListByArtifactId"
            {
                $output = Get-AzureRmResource -ResourceId $ArtifactId -ApiVersion $RequiredApiVersion
            }

            "ListByArtifactName"
            {
                $output = @()

                # first let us extract all the artifact sources associated with the lab.
                $artifactSources = Get-AzureRmResource -ResourceName $Lab.ResourceName -ResourceGroupName $Lab.ResourceGroupName -ResourceType $ArtifactSourceResourceType -ApiVersion $RequiredApiVersion 

                # we'll filter by artifact source name, if specified
                if ($PSBoundParameters.ContainsKey("ArtifactSourceName"))
                {
                    $artifactSources = $artifactSources | Where-Object {
                        $_.Name -eq $ArtifactSourceName
                    }
                }

                # then for each of the artifact sources, let us extract the artifacts themselves.
                foreach ($artifactSrc in $artifactSources)
                {
                    $artifacts = Get-AzureRmResource -ResourceName $($Lab.ResourceName + "/" + $artifactSrc.Name) -ResourceGroupName $Lab.ResourceGroupName -ResourceType $ArtifactResourceType -ApiVersion $RequiredApiVersion

                    # filter by artifact name, if specified
                    if ($PSBoundParameters.ContainsKey("ArtifactName"))
                    {
                        $artifacts = $artifacts | Where-Object {
                            $_.Name -eq $ArtifactName
                        }
                    }

                    # dump the individual artifacts into the output variable
                    foreach ($artifact in $artifacts)
                    {
                        $output += $artifact
                    }
                }
            }
        }

        # now let us display the output
        if ($PSBoundParameters.ContainsKey("ShowProperties"))
        {
            foreach ($item in $output)
            {
                GetResourceWithProperties_Private -Resource $item | Write-Output
            }
        }
        else
        {
            $output | Write-Output
        }
    }
}

##################################################################################################

function Get-AzureRmDtlVhd
{
    <#
        .SYNOPSIS
        Gets vhds from a specified lab.

        .DESCRIPTION
        The Get-AzureRmDtlVhd cmdlet does the following: 
        - Gets a specific vhd from a lab, if the -VhdName parameter is specified.
        - Gets a specific vhd from a lab, if the -VhdUri parameter is specified.
        - Gets all vhds from a lab, if the -Lab parameter is specified.

        .EXAMPLE 
        $lab = $null

        $lab = Get-AzureRmDtlLab -LabName "MyLab1"
        Get-AzureRmDtlVhd -VhdName "myVhd.vhd" -Lab $lab

        Gets a specific vhd "myVhd.vhd" from the lab "MyLab1".

        .EXAMPLE 
        $lab = $null

        $lab = Get-AzureRmDtlLab -LabName "MyLab1"
        Get-AzureRmDtlVhd -VhdAbsoluteUri "https://msdtlvmxxxxxx.blob.core.windows.net/uploads/myVhd.vhd" -Lab $lab

        Gets a specific vhd from the lab "MyLab1".

        .EXAMPLE
        $lab = $null

        $lab = Get-AzureRmDtlLab -LabName "MyLab1"
        Get-AzureRmDtlVhd -Lab $lab

        Gets all vhds from the lab "MyLab1".

        .INPUTS
        None. Currently you cannot pipe objects to this cmdlet (this will be fixed in a future version).  
    #>
    [CmdletBinding(DefaultParameterSetName="ListAllInLab")]
    Param(
        [Parameter(Mandatory=$true, ParameterSetName="ListByVhdName")] 
        [ValidateNotNullOrEmpty()]
        [string]
        # The name of the vhd 
        $VhdName,

        [Parameter(Mandatory=$true, ParameterSetName="ListByVhdUri")] 
        [ValidateNotNullOrEmpty()]
        [string]
        # The absolute uri of the vhd
        $VhdAbsoluteUri,

        [Parameter(Mandatory=$true, ParameterSetName="ListAllInLab")] 
        [Parameter(Mandatory=$true, ParameterSetName="ListByVhdName")] 
        [Parameter(Mandatory=$true, ParameterSetName="ListByVhdUri")] 
        [ValidateNotNull()]
        # An existing lab (please use the Get-AzureRmDtlLab cmdlet to get this lab object).
        $Lab
    )

    PROCESS
    {
        Write-Verbose $("Processing cmdlet '" + $PSCmdlet.MyInvocation.InvocationName + "', ParameterSet = '" + $PSCmdlet.ParameterSetName + "'")

        # Get a context associated with the lab's default storage account.
        Write-Verbose $("Extracting a storage acccount context for the lab '" + $Lab.Name + "'")

        $labStorageAccountContext = New-AzureRmDtlLabStorageContext -Lab $Lab
        if ($null -eq $labStorageAccountContext)
        {
            throw $("Unable to extract a storage account context for the lab '" + $Lab.Name + "'")
        }

        Write-Verbose $("Successfully extracted a storage account context for the lab '" + $Lab.Name + "'")

        # Extract the 'uploads' and 'generatedvhds' container (which houses the vhds).
        Write-Verbose $("Extracting the 'uploads' container")
        $uploadsContainer = Get-AzureStorageContainer -Name "uploads" -Context $labStorageAccountContext

        if ($null -eq $uploadsContainer)
        {
            throw $("Unable to extract the 'uploads' container from the default storage account for lab '" + $Lab.Name + "'")
        }

        Write-Verbose $("Extracting the 'generatedvhds' container")
        $generatedVhdsContainer = Get-AzureStorageContainer -Name "generatedvhds" -Context $labStorageAccountContext

        if ($null -eq $generatedVhdsContainer)
        {
            throw $("Unable to extract the 'generatedvhds' container from the default storage account for lab '" + $Lab.Name + "'")
        }

        #
        $output = $null

        switch ($PSCmdlet.ParameterSetName)
        {
            "ListByVhdName"
            {
                if ($VhdName -notlike "*.vhd")
                {
                    $VhdName = $($VhdName + ".vhd")
                }

                $uploadsImages = Get-AzureStorageBlob -Container $uploadsContainer.Name -Blob $VhdName -Context $labStorageAccountContext -ErrorAction "SilentlyContinue"
                $generatedVhdsImages = Get-AzureStorageBlob -Container $generatedVhdsContainer.Name -Blob $VhdName -Context $labStorageAccountContext -ErrorAction "SilentlyContinue"

                $output = $uploadsImages + $generatedVhdsImages
            }

            "ListByVhdUri"
            {
                $uploadsImages = Get-AzureStorageBlob -Container $uploadsContainer.Name -Context $labStorageAccountContext | Where-Object {
                    ($null -ne $_.ICloudBlob) -and 
                    ($null -ne $_.ICloudBlob.Uri) -and
                    ($null -ne $_.ICloudBlob.Uri.AbsoluteUri) -and
                    ($VhdAbsoluteUri -eq  $_.ICloudBlob.Uri.AbsoluteUri) 
                }

                $generatedVhdsImages = Get-AzureStorageBlob -Container $generatedVhdsContainer.Name -Context $labStorageAccountContext | Where-Object {
                    ($null -ne $_.ICloudBlob) -and 
                    ($null -ne $_.ICloudBlob.Uri) -and
                    ($null -ne $_.ICloudBlob.Uri.AbsoluteUri) -and
                    ($VhdAbsoluteUri -eq  $_.ICloudBlob.Uri.AbsoluteUri) 
                }
                
                $output = $uploadsImages + $generatedVhdsImages
            }

            "ListAllInLab"
            {
                $uploadsImages = Get-AzureStorageBlob -Container $uploadsContainer.Name -Context $labStorageAccountContext
                $generatedVhdsImages = Get-AzureStorageBlob -Container $generatedVhdsContainer.Name -Context $labStorageAccountContext
                
                $output = $uploadsImages + $generatedVhdsImages
            }
        }

        # now let us display the output
        $output | Write-Output
    }
}

##################################################################################################

function Get-AzureRmDtlVirtualMachine
{
    <#
        .SYNOPSIS
        Gets virtual machines under the current subscription.

        .DESCRIPTION
        The Get-AzureRmDtlVirtualMachine cmdlet does the following: 
        - Gets a specific VM, if the -VMId parameter is specified.
        - Gets all VMs in a lab, if the -LabName parameter is specified.

        .EXAMPLE
        Get-AzureRmDtlVirtualMachine -VMId "/subscriptions/xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx/resourceGroups/MyLabRG/providers/Microsoft.DevTestLab/labs/MyLab/environments/MyVM"
        Gets a specific VM, identified by the specified resource-id.

        .EXAMPLE
        $lab = $null

        $lab = Get-AzureRmDtlLab -LabName "MyLab1"
        Get-AzureRmDtlVirtualMachine -Lab $lab
        Gets all VMs within the lab "MyLab1".

        .EXAMPLE
        $lab = $null

        $lab = Get-AzureRmDtlLab -LabName "MyLab1"
        Get-AzureRmDtlVirtualMachine -Lab $lab -VmName "MyVm"
        Gets VM "MyVm" within the lab "MyLab1".

        .INPUTS
        None. Currently you cannot pipe objects to this cmdlet (this will be fixed in a future version).  
    #>
    [CmdletBinding()]
    Param(
        [Parameter(Mandatory=$true, ParameterSetName="ListByVMId")] 
        [ValidateNotNullOrEmpty()]
        [string]
        # The ResourceId of the VM (e.g. "/subscriptions/xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx/resourceGroups/MyLabRG/providers/Microsoft.DevTestLab/environments/MyVM").
        $VMId,

        [Parameter(Mandatory=$true, ParameterSetName="ListByVMName")] 
        [ValidateNotNull()]
        # An existing lab (please use the Get-AzureRmDtlLab cmdlet to get this lab object).
        $Lab,

        [Parameter(Mandatory=$false, ParameterSetName="ListByVMName")] 
        [ValidateNotNullOrEmpty()]
        [string]
        # Name of the VM to fetch from the lab.
        $VMName,

        [Parameter(Mandatory=$false, ParameterSetName="ListByVMId")] 
        [Parameter(Mandatory=$false, ParameterSetName="ListByVMName")]
        [switch]
        # Optional. If specified, fetches the properties of the virtual machine(s).
        $ShowProperties
    )

    PROCESS
    {
        Write-Verbose $("Processing cmdlet '" + $PSCmdlet.MyInvocation.InvocationName + "', ParameterSet = '" + $PSCmdlet.ParameterSetName + "'")

        $output = $null

        switch($PSCmdlet.ParameterSetName)
        {
            "ListByVMId"
            {
                $output = Get-AzureRmResource | Where-Object { 
                    $_.ResourceType -eq $VirtualMachineResourceType -and 
                    $_.ResourceId -eq $VMId 
                }
            }

            "ListByVMName"
            {
                $resourceName = $Lab.Name
                if ($false -eq [string]::IsNullOrEmpty($VMName))
                {
                    $resourceName = $resourceName + "/" + $VMName
                }

                # Note: The -ErrorAction 'SilentlyContinue' ensures that we suppress irrelevant
                # errors originating while expanding properties (especially in internal test and
                # pre-production subscriptions).                
                $output = Get-AzureRmResource -ExpandProperties -ErrorAction "SilentlyContinue" | Where-Object { 
                    $_.ResourceType -eq $VirtualMachineResourceType -and
                    $_.ResourceGroupName -eq $Lab.ResourceGroupName
                }
                
                if ($PSBoundParameters.ContainsKey("VMName"))
                {
                    $output = $output | Where-Object {
                        $_.Name -eq $VMName -and
                        $_.ResourceName -eq $($Lab.Name + "/" + $VMName)
                    }
                }
            }
        }

        # now let us display the output
        if ($PSBoundParameters.ContainsKey("ShowProperties"))
        {
            foreach ($item in $output)
            {
                GetResourceWithProperties_Private -Resource $item | Write-Output
            }
        }
        else
        {
            $output | Write-Output
        }
    }
}

##################################################################################################

function New-AzureRmDtlLab
{
    <#
        .SYNOPSIS
        Creates a new lab.

        .DESCRIPTION
        The New-AzureRmDtlLab cmdlet creates a new lab in the specified location.

        .EXAMPLE
        New-AzureRmDtlLab -LabName "MyLab1" -LabLocation "West US"
        Creates a new lab "MyLab1" in the location "West US".

        .INPUTS
        None. Currently you cannot pipe objects to this cmdlet (this will be fixed in a future version).  
    #>
    [CmdletBinding()]
    Param(
        [Parameter(Mandatory=$true)] 
        [ValidateNotNullOrEmpty()]
        [string]
        # Name of lab to be created.
        $LabName,

        [Parameter(Mandatory=$true)] 
        [ValidateNotNullOrEmpty()]
        [string]
        # Location where the lab will be created.
        $LabLocation
    )

    PROCESS 
    {
        Write-Verbose $("Processing cmdlet '" + $PSCmdlet.MyInvocation.InvocationName + "', ParameterSet = '" + $PSCmdlet.ParameterSetName + "'")

        # Unique name for the deployment
        $deploymentName = [Guid]::NewGuid().ToString()

        # Folder location of VM creation script, the template file and template parameters file.
        $LabCreationTemplateFile = Join-Path $PSScriptRoot -ChildPath $ARMTemplate_CreateLab -Resolve

        # Pre-condition check to ensure the RM template file exists.
        if ($false -eq (Test-Path -Path $LabCreationTemplateFile))
        {
            throw $("The RM template file could not be located at : '" + $LabCreationTemplateFile + "'")
        }
        else
        {
            Write-Verbose $("The RM template file was located at : '" + $LabCreationTemplateFile + "'")
        }

        # Check if there are any existing labs with same name in the current subscription
        $existingLabs = Get-AzureRmResource | Where-Object { 
            $_.ResourceType -eq $LabResourceType -and 
            $_.ResourceName -eq $LabName -and 
            $_.SubscriptionId -eq (Get-AzureRmContext).Subscription.SubscriptionId
        }

        # If none exist, then create a new one
        if ($null -eq $existingLabs -or 0 -eq $existingLabs.Count)
        {
            # Create a new resource group with a unique name (using the lab name as a seed/prefix).
            Write-Verbose $("Creating new resoure group with seed/prefix '" + $LabName + "' at location '" + $LabLocation + "'")
            $newResourceGroup = CreateNewResourceGroup_Private -ResourceGroupSeedPrefixName $LabName -Location $LabLocation
            Write-Verbose $("Successfully created new resoure group '" + $newResourceGroup.ResourceGroupName + "' at location '" + $newResourceGroup.Location + "'")
    
            # Create the lab in this resource group by deploying the RM template
            Write-Verbose $("Creating new lab '" + $LabName + "'")
            $rgDeployment = New-AzureRmResourceGroupDeployment -Name $deploymentName -ResourceGroupName $newResourceGroup.ResourceGroupName  -TemplateFile $LabCreationTemplateFile -newLabName $LabName 

            if (($null -ne $rgDeployment) -and ($null -ne $rgDeployment.Outputs['labId']) -and ($null -ne $rgDeployment.Outputs['labId'].Value))
            {
                $labId = $rgDeployment.Outputs['labId'].Value

                Write-Verbose $("LabId : '" + $labId + "'")

                Get-AzureRmResource -ResourceId $labId | Write-Output
            }
        }

        # else display an error
        else
        {
            throw $("One or more labs with name '" + $LabName + "' already exist in the current subscription '" + (Get-AzureRmContext).Subscription.SubscriptionId + "'.")
        }
    }
}

##################################################################################################

function New-AzureRmDtlLabStorageContext
{
    <#
        .SYNOPSIS
        Creates an Azure storage context from the lab's storage account.

        .DESCRIPTION
        The New-AzureRmDtlLabStorageContext cmdlet creates an Azure storage context from the
        storage account associated with the specified lab.

        .EXAMPLE
        $lab = $null

        $lab = Get-AzureRmDtlLab -LabName "MyLab1"
        New-AzureRmDtlLabStorageContext -Lab $lab

        Creates a new storage context from the storage account of the lab "MyLab1".

        .INPUTS
        None. Currently you cannot pipe objects to this cmdlet (this will be fixed in a future version).  
    #>

    [CmdletBinding()]
    Param(
        [Parameter(Mandatory=$true)] 
        [ValidateNotNull()]
        # An existing Lab (please use the Get-AzureRmDtlLab cmdlet to get this lab object).
        $Lab
    )

    PROCESS
    {
        Write-Verbose $("Processing cmdlet '" + $PSCmdlet.MyInvocation.InvocationName + "', ParameterSet = '" + $PSCmdlet.ParameterSetName + "'")

        # Get the same lab object, but with properties attached.
        $lab = GetResourceWithProperties_Private -Resource $Lab

        # Get the default storage account associated with the lab.
        Write-Verbose $("Extracting the default storage account for lab '" + $Lab.Name +"'")

        $labStorageAccount = Get-AzureRmResource | Where-Object {
            $_.ResourceType -eq $StorageAccountResourceType -and 
            $_.ResourceId -eq $lab.Properties.DefaultStorageAccount
        }

        if ($null -eq $labStorageAccount)
        {
            throw $("Unable to extract the default storage account for lab '" + $Lab.Name + "'")
        }

        Write-Verbose $("Successfully extracted the default storage account for lab '" + $Lab.Name +"'")

        # Extracting the lab's storage account key
        Write-Verbose $("Extracting the storage account key for lab '" + $Lab.Name +"'")

        $labStorageAccountKey = Get-AzureRmStorageAccountKey -ResourceGroupName $labStorageAccount.ResourceGroupName -Name $labStorageAccount.ResourceName

        if ($null -eq $labStorageAccountKey)
        {
            throw $("Unable to extract the storage account key for lab '" + $Lab.Name + "'")
        }

        Write-Verbose $("Successfully extracted the storage account key for lab '" + $Lab.Name +"'")

        # Create a new storage context using the lab's default storage account .
        New-AzureStorageContext -StorageAccountName $labStorageAccount.ResourceName -StorageAccountKey $labStorageAccountKey[0].Value | Write-Output
    }
}

##################################################################################################

function New-AzureRmDtlCustomImage
{
    <#
        .SYNOPSIS
        Creates a new virtual machine custom image.

        .DESCRIPTION
        The New-AzureRmDtlCustomImage cmdlet creates a new custom image from an existing VM or Vhd.
        - The custom image name can only include alphanumeric characters, underscores, hyphens and parantheses.
        - The new custom image is created in the same lab as the VM (or vhd).

        .EXAMPLE
        $lab = $null

        $lab = Get-AzureRmDtlLab -LabName "MyLab"
        $vm = Get-AzureRmDtlVirtualMachine -VMName "MyVM1" -Lab $lab
        New-AzureRmDtlCustomImage -SrcDtlVM $vm -DestCustomImageName "MyCustomImage1" -DestCustomImageDescription "MyDescription"

        Creates a new custom image "MyCustomImage1" from the VM "MyVM1" (in the same lab as the VM).

        .EXAMPLE
        $lab = $null

        $lab = Get-AzureRmDtlLab -LabName "MyLab1"
        $vhd = Get-AzureRmDtlVhd -Lab $lab -VhdName "MyVhd1.vhd"
        New-AzureRmDtlCustomImage -SrcDtlVhd $vhd -SrcDtlLab $lab -DestCustomImageName "MyCustomImage1" -DestCustomImageDescription "MyDescription" -SrcImageOSType windows

        Creates a new custom image "MyCustomImage1" in the lab "MyLab1" using the vhd "MyVhd1.vhd" from the same lab.

        .INPUTS
        None.
    #>
    [CmdletBinding(DefaultParameterSetName="FromVM")]
    Param(
        [Parameter(Mandatory=$true, ParameterSetName="FromVM")]
        [ValidateNotNull()]
        # An existing lab VM from which the new lab custom image will be created (please use the Get-AzureRmDtlVirtualMachine cmdlet to get this lab VM object).
        $SrcDtlVM,

        [Parameter(Mandatory=$true, ParameterSetName="FromVhd")]
        [ValidateNotNull()]
        # An existing lab vhd from which the new lab custom image will be created (please use the Get-AzureRmDtlVhd cmdlet to get this lab vhd object).
        $SrcDtlVhd,

        [Parameter(Mandatory=$true, ParameterSetName="FromVhd")]
        [ValidateNotNull()]
        # An existing lab where the source vhd resides (please use the Get-AzureRmDtlLab cmdlet to get this lab object).
        $SrcDtlLab,

        [Parameter(Mandatory=$true, ParameterSetName="FromVhd")]
        [ValidateSet("windows", "linux")]        
        [string]
        # The OS type of the source Vhd or Azure gallery image. 
        # Note: Currently "windows" and "linux" are the only supported values.
        # Note: This parameter is ignored when '-SrcDtlVM' is used.
        $SrcImageOSType,

        [Parameter(Mandatory=$false, ParameterSetName="FromVM")]
        [Parameter(Mandatory=$false, ParameterSetName="FromVhd")]
        [switch]
        # Specifies whether the source VM or Vhd is sysprepped. 
        # Note: This parameter is ignored when a linux VHD or VM is used as the source for the new custom image.
        # Note: This parameter is ignored when an Azure gallery image is used as the source for the new custom image.
        $SrcIsSysPrepped,
        
        [Parameter(Mandatory=$false, ParameterSetName="FromVM")]
        [Parameter(Mandatory=$false, ParameterSetName="FromVhd")]
        [string]
        # Specifies whether the source VM or Vhd is sysprepped. 
        # Note: This parameter is ignored when a linux VHD or VM is used as the source for the new custom image.
        # Note: This parameter has three acceptable values, SysprepRequested, SysprepApplied, and NonSysprepped.
        # Note: This parameter is ignored when an Azure gallery image is used as the source for the new custom image.
        $windowsOsState,
        
        [Parameter(Mandatory=$false, ParameterSetName="FromVM")]
        [Parameter(Mandatory=$false, ParameterSetName="FromVhd")]
        [string]
        # Specifies whether the source VM or Vhd is sysprepped. 
        # Note: This parameter is ignored when a Windows VHD or VM is used as the source for the new custom image.
        # Note: This parameter has three acceptable values, DeprovisionRequested, DeprovisionApplied, and NonDeprovisioned.
        # Note: This parameter is ignored when an Azure gallery image is used as the source for the new custom image.
        $linuxOsState,
        
        [Parameter(Mandatory=$false, ParameterSetName="FromVM")]
        [Parameter(Mandatory=$false, ParameterSetName="FromVhd")]
        [string]
        # Specifies the Linux Distribution. 
        # Note: This parameter is ignored when a Windows VHD or VM is used as the source for the new custom image.
        # Note: Acceptable Values for this command are: CentOs, Debian, Oracale, SLES, Ubuntu, Ubuntu15
        # Note: This parameter is ignored when an Azure gallery image is used as the source for the new custom image.
        $distribution,
        
        [Parameter(Mandatory=$true, ParameterSetName="FromVM")]
        [Parameter(Mandatory=$true, ParameterSetName="FromVhd")]
        [ValidateNotNullOrEmpty()]
        [string]
        # Name of the new lab custom image to be created.
        $DestCustomImageName,

        [Parameter(Mandatory=$false, ParameterSetName="FromVM")]
        [Parameter(Mandatory=$false, ParameterSetName="FromVhd")]
        [ValidateNotNull()]
        [string]
        # Details about the new lab custom image being created.
        $DestCustomImageDescription = ""
    )

    PROCESS
    {
        Write-Verbose $("Processing cmdlet '" + $PSCmdlet.MyInvocation.InvocationName + "', ParameterSet = '" + $PSCmdlet.ParameterSetName + "'")

        # Pre-condition check for the custom image name
        if ($true -eq ($DestCustomImageName -match "[^0-9a-zA-Z()_-]"))
        {
            throw $("Invalid characters detected in the supplied custom image name '" + $DestCustomImageName + "'. The custom image name can only include alphanumeric characters, underscores, hyphens and parantheses.")
        }

        # Encode the custom image name
        $destCustomImageNameEncoded = $DestCustomImageName.Replace(" ", "%20")

        # Unique name for the deployment
        $deploymentName = [Guid]::NewGuid().ToString()

        switch($PSCmdlet.ParameterSetName)
        {
            "FromVM"
            {
                                
                if ("windows" -eq $SrcImageOSType)
                {
                    $windowsOsState = $PSBoundParameters.ContainsKey("windowsOsState")
                }
                               
                # Get the same VM object, but with properties attached.
                $SrcDtlVM = GetResourceWithProperties_Private -Resource $SrcDtlVM

                # Pre-condition checks to ensure that VM is in a valid state.
                if (($null -ne $SrcDtlVM) -and ($null -ne $SrcDtlVM.Properties) -and ($null -ne $SrcDtlVM.Properties.ProvisioningState))
                {
                    if ("succeeded" -ne $SrcDtlVM.Properties.ProvisioningState)
                    {
                        throw $("The provisioning state of the VM '" + $SrcDtlVM.ResourceName + "' is '" + $SrcDtlVM.Properties.ProvisioningState + "'. Hence unable to continue.")
                    }
                }
                else
                {
                    throw $("The provisioning state of the VM '" + $SrcDtlVM.ResourceName + "' could not be determined. Hence unable to continue.")
                }

                # Pre-condition checks to ensure that we're able to extract the Resource Id of the compute VM.
                if ($null -eq $SrcDtlVM.ResourceId)
                {
                    throw $("Unable to determine the Resource Id of the compute VM '" + $SrcDtlVM.ResourceName + "'.")
                }

                # Folder location of VM creation script, the template file and template parameters file.
                if ((($null -ne $SrcDtlVM.Properties.OsProfile) -and ($null -ne $SrcDtlVM.Properties.OsProfile.WindowsConfiguration)) -or
                    (($null -ne $SrcDtlVM.Properties.GalleryImageReference) -and ("Windows" -eq $SrcDtlVM.Properties.GalleryImageReference.OsType)) -or
                    ($null -ne $windowsOsState))
                {
                    Write-Verbose "Detected OS type: Windows"
                    $templateName = $ARMTemplate_CreateCustomImage_FromWindowsVM
                }
                else
                {
                    Write-Verbose "Detected OS type: Linux"
                    $templateName = $ARMTemplate_CreateCustomImage_FromLinuxVM
                }

                $CustomImageCreationTemplateFile = Join-Path $PSScriptRoot -ChildPath $templateName -Resolve

                # Pre-condition check to ensure the RM template file exists.
                if ($false -eq (Test-Path -Path $CustomImageCreationTemplateFile))
                {
                    throw $("The RM template file could not be located at : '" + $CustomImageCreationTemplateFile + "'")
                }
                else
                {
                    Write-Verbose $("The RM template file was located at : '" + $CustomImageCreationTemplateFile + "'")
                }

                # Get the lab that contains the source VM
                $lab = GetLabFromVM_Private -VM $SrcDtlVM

                # Pre-condition check to ensure that a custom image with same name doesn't already exist.
                $destCustomImageExists = ($null -ne (Get-AzureRmDtlCustomImage -CustomImageName $DestCustomImageName -Lab $lab)) 

                if ($true -eq $destCustomImageExists)
                {
                    throw $("A custom image with the name '" + $DestCustomImageName + "' already exists in the lab '" + $lab.Name + "'. Please specify another name for the custom image to be created.")
                }

                # If the Os Type is Linux we will seed the Old property bag excluding WindowsOsInfo
                # Is sysprepped is set to false in the Arm Template
                if("linux" -eq $SrcImageOSType)
                {
                    $rgDeployment = New-AzureRmResourceGroupDeployment -Name $deploymentName -ResourceGroupName $lab.ResourceGroupName -TemplateFile $CustomImageCreationTemplateFile -existingLabName $lab.ResourceName -existingVMResourceId $SrcDtlVM.ResourceId -linuxOsState $linuxOsState -imageName $destCustomImageNameEncoded -imageDescription $DestCustomImageDescription -ErrorAction "Stop"
                }
                else
                {
                    # Create the custom image in the lab's resource group by deploying the RM template
                    Write-Verbose $("Creating custom image '" + $DestCustomImageName + "' in lab '" + $lab.ResourceName + "'")
                    $rgDeployment = New-AzureRmResourceGroupDeployment -Name $deploymentName -ResourceGroupName $lab.ResourceGroupName -TemplateFile $CustomImageCreationTemplateFile -existingLabName $lab.ResourceName -existingVMResourceId $SrcDtlVM.ResourceId -windowsOsState $windowsOsState -imageName $destCustomImageNameEncoded -imageDescription $DestCustomImageDescription -ErrorAction "Stop"
                }
            }

            "FromVhd"
            {
                # Ignore 'sysprep' for non-Windows vhds.
                $isSysPrepped = $PSBoundParameters.ContainsKey("SrcIsSysPrepped")

                if ("linux" -eq $SrcImageOSType)
                {
                    $isSysPrepped = $false    
                }

                # Pre-condition checks to ensure that we're able to extract the uri of the vhd blob.
                if (($null -eq $SrcDtlVhd.ICloudBlob) -or ($null -eq $SrcDtlVhd.ICloudBlob.Uri) -or ($null -eq $SrcDtlVhd.ICloudBlob.Uri.AbsoluteUri))
                {
                    throw $("Unable to determine the absolute uri of the vhd '" + $SrcDtlVhd.Name + "'.")
                }

                # Folder location of VM creation script, the template file and template parameters file.
                $CustomImageCreationTemplateFile = Join-Path $PSScriptRoot -ChildPath $ARMTemplate_CreateCustomImage_FromVhd -Resolve

                # Pre-condition check to ensure the RM template file exists.
                if ($false -eq (Test-Path -Path $CustomImageCreationTemplateFile))
                {
                    throw $("The RM template file could not be located at : '" + $CustomImageCreationTemplateFile + "'")
                }
                else
                {
                    Write-Verbose $("The RM template file was located at : '" + $CustomImageCreationTemplateFile + "'")
                }

                # Pre-condition check to ensure that src vhd indeed belongs to the src lab.
                $vhd = Get-AzureRmDtlVhd -VhdAbsoluteUri $SrcDtlVhd.ICloudBlob.Uri.AbsoluteUri -Lab $SrcDtlLab

                if (($null -eq $vhd) -or ($vhd.ICloudBlob.Uri.AbsoluteUri -ne $SrcDtlVhd.ICloudBlob.Uri.AbsoluteUri))
                {
                    throw $("The specified vhd '" + $SrcDtlVhd.Name + "' could not be located in the lab '" + $SrcDtlLab.Name + "'.")
                }

                # Pre-condition check to ensure that a custom image with same name doesn't already exist.
                $destCustomImageExists = ($null -ne (Get-AzureRmDtlCustomImage -CustomImageName $DestCustomImageName -Lab $SrcDtlLab)) 

                if ($true -eq $destCustomImageExists)
                {
                    throw $("A custom image with the name '" + $DestCustomImageName + "' already exists in the lab '" + $SrcDtlLab.Name + "'. Please specify another name for the custom image to be created.")
                }

                # Create the custom image in the lab's resource group by deploying the RM template
                Write-Verbose $("Creating custom image '" + $DestCustomImageName + "' in lab '" + $SrcDtlLab.ResourceName + "'")
                $rgDeployment = New-AzureRmResourceGroupDeployment -Name $deploymentName -ResourceGroupName $SrcDtlLab.ResourceGroupName -TemplateFile $CustomImageCreationTemplateFile -existingLabName $SrcDtlLab.ResourceName -existingVhdUri $SrcDtlVhd.ICloudBlob.Uri.AbsoluteUri -imageOsType $SrcImageOSType -isVhdSysPrepped $isSysPrepped -imageName $destCustomImageNameEncoded -imageDescription $DestCustomImageDescription -ErrorAction "Stop"
            }
        }

        # fetch and output the newly created custom image. 
        if (($null -ne $rgDeployment) -and ($null -ne $rgDeployment.Outputs['customImageId']) -and ($null -ne $rgDeployment.Outputs['customImageId'].Value))
        {
            $customImageId = $rgDeployment.Outputs['customImageId'].Value
            Write-Verbose $("CustomImageId : '" + $customImageId + "'")

            Get-AzureRmResource -ResourceId $customImageId -ApiVersion $RequiredApiVersion | Write-Output
        }
    }
}

##################################################################################################

function Add-AzureRmDtlVhd
{
    <#
        .SYNOPSIS
        Uploads a local or remote vhd into the specified lab.

        .DESCRIPTION
        The Add-AzureRmDtlVhd cmdlet uploads a vhd into a lab. The source vhd must reside on:
        - local drives (e.g. c:\somefolder\somefile.ext) OR
        - UNC shares (e.g. \\someshare\somefolder\somefile.ext) OR
        - Network mapped drives (e.g. net use z: \\someshare\somefolder && z:\somefile.ext). 

        If your source vhd is stored as blob in an Azure storage account, please use the Start-AzureRmDtlVhdCopy
        cmdlet instead.

        Please note that the vhd file must meet the following specific requirements (dictated by Azure):
        - Must be a Gen1 vhd file (and NOT a Gen2 vhdx file).
        - Fixed sized vhd (and NOT dynamically expanding vhd). 
        - Size must be less than 1023 GB. 
        - The vhd must be uploaded as a page blob (and NOT as a block blob).

        Other notes:
        - Vhds are validated to ensure they meet the Azure requirements. If validation is successful, they 
          are uploaded to the destination lab.
        - For perf reasons, if you have a remote vhd (on a UNC share or on a network mapped drive), it is
          recommended that you copy it a local disk, before calling this cmdlet. 

        .EXAMPLE
        $destLab = $null

        $destLab = Get-AzureRmDtlLab -LabName "MyLab"
        Add-AzureRmDtlVhd -SrcVhdPath "d:\myImages\MyOriginal.vhd" -DestLab $destLab -DestVhdName "MyRenamed.vhd"

        Uploads a local vhd "MyOriginal.vhd" into the lab "MyLab" as "MyRenamed.vhd".

        .EXAMPLE
        $destLab = $null

        $destLab = Get-AzureRmDtlLab -LabName "MyLab"
        Add-AzureRmDtlVhd -SrcVhdPath "\\MyShare\MyFolder\MyOriginal.vhd" -DestLab $lab 

        Uploads a vhd file "MyOriginal.vhd" from specified network share "\\MyShare\MyFolder" into the lab "MyLab". 

        .INPUTS
        None. Currently you cannot pipe objects to this cmdlet (this will be fixed in a future version).  
    #>
    [CmdletBinding(SupportsShouldProcess=$true)]
    Param(
        [Parameter(Mandatory=$true)] 
        [ValidateNotNullOrEmpty()]
        [string]
        # Full path to the vhd file (that'll be uploaded to the lab).
        # Note: Currently we only support vhds that are available from:
        # - local drives (e.g. c:\somefolder\somefile.ext)
        # - UNC shares (e.g. \\someshare\somefolder\somefile.ext).
        # - Network mapped drives (e.g. net use z: \\someshare\somefolder && z:\somefile.ext). 
        $SrcVhdPath,

        [Parameter(Mandatory=$true)] 
        [ValidateNotNull()]
        # An existing lab to which the vhd will be uploaded (please use the Get-AzureRmDtlLab cmdlet to get this lab object).
        $DestLab,

        [Parameter(Mandatory=$false)] 
        [string]
        # [Optional] The name that will be assigned to vhd once uploded to the lab.
        # The name should be in a "<filename>.vhd" format (E.g. "WinServer2012-VS2015.Vhd"). 
        $DestVhdName,

        [Parameter(Mandatory=$false)] 
        [ValidateScript({$_ -ge 1})]
        [int]
        # [Optional] The number of uploader threads to use.
        # Note: By default, the numer of uploader threads used is equal to the number of processors.  
        $NumThreads = $env:NUMBER_OF_PROCESSORS,

        [Parameter(Mandatory=$false)] 
        [switch]
        # [Optional] If specified, will overwrite any existing vhd with the same name in the lab.
        $OverWrite
    )

    PROCESS
    {
        Write-Verbose $("Processing cmdlet '" + $PSCmdlet.MyInvocation.InvocationName + "', ParameterSet = '" + $PSCmdlet.ParameterSetName + "'")

        # Check if the specified vhd actually exists
        if ($false -eq (Test-Path -Path $SrcVhdPath))
        {
            throw $("Specified vhd is not accessible: " + $SrcVhdPath)
        }

        # If the user has specified a name for the destination name, ensure that it is appended with ".vhd" extension. 
        if ([string]::IsNullOrEmpty($DestVhdName))
        {
            $DestVhdName = Split-Path -Path $SrcVhdPath -Leaf
        }
        else
        {
            if ($DestVhdName -notlike "*.vhd")
            {
                $DestVhdName = $($DestVhdName + ".vhd")
            }
        }

        # Get a context associated with the lab's default storage account.
        Write-Verbose $("Extracting a storage acccount context for the lab '" + $DestLab.Name + "'")

        $destStorageAccountContext = New-AzureRmDtlLabStorageContext -Lab $DestLab

        if ($null -eq $destStorageAccountContext)
        {
            throw $("Unable to extract the storage account context for lab '" + $DestLab.Name + "'")
        }

        Write-Verbose $("Successfully extracted a storage account context for the lab '" + $DestLab.Name + "'")

        # Extract the 'uploads' container (which houses the vhds).
        $destContainer = Get-AzureStorageContainer -Name "uploads" -Context $destStorageAccountContext

        if ($null -eq $destContainer)
        {
            throw $("Unable to extract the 'uploads' container from the default storage account of lab '" + $DestLab.Name + "'")
        }

        # Processing the -Confirm and -Whatif switches.
        if ($PSCmdlet.ShouldProcess($DestVhdName, "Add Vhd"))
        {
            # Compute the destination vhd uri. 
            $destVhdUri = $($destContainer.CloudBlobContainer.Uri.AbsoluteUri + "/" + $DestVhdName) 

            # Now upload the vhd to lab's container
            Write-Warning "Starting upload of vhd to lab (Note: This can take a while)..."
            Write-Verbose "Starting upload of vhd to lab (Note: This can take a while)..."
            Write-Verbose $("Source: " + $SrcVhdPath)
            Write-Verbose $("Destination: " + $destVhdUri)
        
            # let us measure the file upload time for instrumentation purposes.
            $stopWatch = [Diagnostics.Stopwatch]::StartNew()

            # Now upload the vhd to the lab.
            Add-AzureRmVhd -Destination $destVhdUri -LocalFilePath $SrcVhdPath -ResourceGroupName $DestLab.ResourceGroupName -NumberOfUploaderThreads $NumThreads -OverWrite:$PSBoundParameters.ContainsKey("OverWrite") | Out-Null

            if ($false -eq $?)
            {
                throw "An error occurred while copying the vhd to the lab '" + $DestLab.Name + "'."
            }    

            $stopWatch.Stop()
            Write-Verbose $("Successfully uploaded vhd to the lab in " + $stopWatch.Elapsed.TotalSeconds + " seconds.")

            # fetch and return the vhd which was just uploaded
            Get-AzureRmDtlVhd -Lab $DestLab -VhdAbsoluteUri $destVhdUri | Write-Output
        }
    }
}

##################################################################################################

function Start-AzureRmDtlVhdCopy
{
    <#
        .SYNOPSIS
        Starts to copy a vhd from an Azure storage account into the specified lab.

        .DESCRIPTION
        The Add-AzureRmDtlVhd cmdlet starts a copy operation to upload a vhd into a lab. The source vhd 
        must reside:
        - as blobs in Azure storage containers.
        - as files on Azure file shares (currently not supported).

        If your source vhd is located on a local disk or a network share, please use the Add-AzureRmDtlVhd 
        cmdlet instead.

        Please note that the vhd file must meet the following specific requirements (dictated by Azure):
        - Must be a Gen1 vhd file (and NOT a Gen2 vhdx file).
        - Fixed sized vhd (and NOT dynamically expanding vhd). 
        - Size must be less than 1023 GB. 
        - The vhd must be uploaded as a page blob (and NOT as a block blob).

        Other notes:
        - Vhds from Azure storage containers are copied directly into the lab (without being staged and validated locally).  

        .EXAMPLE
        $destLab = $null

        $destLab = Get-AzureRmDtlLab -LabName "MyLab" 

        $destVhd = Start-AzureRmDtlVhdCopy -SrcVhdBlobName "MyOriginal.vhd" -SrcVhdContainerName "MyContainer1" -SrcVhdStorageAccountName "MyStorageAccount1" -SrcVhdStorageAccountKey "xxxxxxx" -DestLab $destLab -WaitForCompletion

        Initiates copying of vhd file "MyOriginal.vhd" from the storage account "MyStorageAccount1" into the lab "MyLab" and waits
        for the copy operation to fully complete. 
        
        Note: When the '-WaitForCompletion' switch is specified, this cmdlet's output is the vhd object which was successfully 
        copied into the destination lab.

        .EXAMPLE
        $srcLab = $null

        $srcLab = Get-AzureRmDtlLab -LabName "MySrcLab"
        $srcVhd = Get-AzureRmDtlVhd -Lab $srcLab -VhdName "MyOriginal.vhd"

        $destLab = Get-AzureRmDtlLab -LabName "MyDestLab"

        $destVhd = Start-AzureRmDtlVhdCopy -SrcDtlVhd $srcVhd -SrcDtlLab $srcLab -DestLab $destLab -WaitForCompletion

        Initiates copying of vhd file "MyOriginal.vhd" from the lab "MySrcLab" into the lab "MyDestLab" and waits
        for the copy operation to fully complete. 
        
        Note: When the '-WaitForCompletion' switch is specified, this cmdlet's output is the vhd object which was successfully 
        copied into the destination lab.

        .EXAMPLE
        $destLab = $null

        $destLab = Get-AzureRmDtlLab -LabName "MyLab"
        $destLabStorageContext = New-AzureRmDtlLabStorageContext -Lab $destLab

        $destVhdName = "MyRenamed.vhd"

        $destVhd = Start-AzureRmDtlVhdCopy -SrcVhdBlobName "MyOriginal.vhd" -SrcVhdContainerName "MyContainer1" -SrcVhdStorageAccountName "MyStorageAccount1" -SrcVhdStorageAccountKey "xxxxxxx" -DestLab $destLab -DestVhdName $destVhdName

        Get-AzureStorageBlobCopyState -Blob $destVhdName -Container "uploads" -Context $destLabStorageContext

        Initiates copying of vhd file "MyOriginal.vhd" from the storage account "MyStorageAccount1" into the lab "MyLab" as "MyRenamed.vhd", but does
        not wait for the copy operation to complete.

        Note: When the '-WaitForCompletion' switch is not specified, this cmdlet's output is the vhd object partially copied into the destination 
        lab. The status of the copy-operation can be queried by using the 'New-AzureRmDtlLabStorageContext' and 'get-AzureStorageBlobCopyState' cmdlets 
        as shown above.

        .INPUTS
        None. Currently you cannot pipe objects to this cmdlet (this will be fixed in a future version).  
    #>
    [CmdletBinding(
        SupportsShouldProcess=$true,
        DefaultParameterSetName="CopyVhdFromStorageContainer")]
    Param(
        [Parameter(Mandatory=$true, ParameterSetName="CopyVhdFromStorageContainer")] 
        [ValidateNotNullOrEmpty()]
        [string]
        # The name of the blob representing the vhd file (that'll be uploaded to the lab).
        $SrcVhdBlobName,

        [Parameter(Mandatory=$true, ParameterSetName="CopyVhdFromStorageContainer")] 
        [ValidateNotNullOrEmpty()]
        [string]
        # The name of the container representing the vhd file (that'll be uploaded to the lab).
        $SrcVhdContainerName,

        [Parameter(Mandatory=$true, ParameterSetName="CopyVhdFromStorageContainer")] 
        [ValidateNotNullOrEmpty()]
        [string]
        # The name of the storage account associated with the vhd file (that'll be uploaded to the lab).
        $SrcVhdStorageAccountName,

        [Parameter(Mandatory=$true, ParameterSetName="CopyVhdFromStorageContainer")] 
        [ValidateNotNullOrEmpty()]
        [string]
        # The key of the storage account associated with the vhd file (that'll be uploaded to the lab).
        $SrcVhdStorageAccountKey,

        [Parameter(Mandatory=$true, ParameterSetName="CopyVhdFromLab")] 
        [ValidateNotNull()]
        # An existing lab vhd that'll be copied from its source lab to the destination lab (please use the Get-AzureRmDtlVhd cmdlet to get this vhd object).
        $SrcDtlVhd,

        [Parameter(Mandatory=$true, ParameterSetName="CopyVhdFromLab")]
        [ValidateNotNull()]
        # An existing lab where the source vhd resides (please use the Get-AzureRmDtlLab cmdlet to get this lab object).
        $SrcDtlLab,

        [Parameter(Mandatory=$true, ParameterSetName="CopyVhdFromStorageContainer")] 
        [Parameter(Mandatory=$true, ParameterSetName="CopyVhdFromLab")] 
        [ValidateNotNull()]
        # An existing lab to which the vhd will be uploaded (please use the Get-AzureRmDtlLab cmdlet to get this lab object).
        $DestLab,

        [Parameter(Mandatory=$false, ParameterSetName="CopyVhdFromStorageContainer")] 
        [Parameter(Mandatory=$false, ParameterSetName="CopyVhdFromLab")] 
        [string]
        # [Optional] The name that will be assigned to vhd once uploded to the lab.
        # The name should be in a "<filename>.vhd" format (E.g. "WinServer2012-VS2015.Vhd"). 
        $DestVhdName,

        [Parameter(Mandatory=$false, ParameterSetName="CopyVhdFromStorageContainer")] 
        [Parameter(Mandatory=$false, ParameterSetName="CopyVhdFromLab")] 
        [ValidateScript({$_ -ge 1})]
        [int]
        # [Optional] The number of uploader threads to use.
        # Note: By default, the numer of uploader threads used is equal to the number of processors.  
        $NumThreads = $env:NUMBER_OF_PROCESSORS,

        [Parameter(Mandatory=$false, ParameterSetName="CopyVhdFromStorageContainer")] 
        [Parameter(Mandatory=$false, ParameterSetName="CopyVhdFromLab")] 
        [switch]
        # [Optional] If specified, will overwrite any existing vhd with the same name in the lab.
        $OverWrite,

        [Parameter(Mandatory=$false, ParameterSetName="CopyVhdFromStorageContainer")] 
        [Parameter(Mandatory=$false, ParameterSetName="CopyVhdFromLab")] 
        [switch]
        # [Optional] If specified, will wait for vhd copy operation to complete.
        $WaitForCompletion
    )

    PROCESS 
    {
        Write-Verbose $("Processing cmdlet '" + $PSCmdlet.MyInvocation.InvocationName + "', ParameterSet = '" + $PSCmdlet.ParameterSetName + "'")

        #
        # Section #1: Figure out that destination storage details
        # 

        $myDestBlobName = $null
        $myDestBlobUri = $null
        $myDestBlobExists = $null
        $myDestContainer = $null
        $myDestContainerName = $null
        $myDestStorageContext = $null

        # If the user has specified a name for the destination name, ensure that it is appended with ".vhd" extension. 
        if ($false -eq [string]::IsNullOrEmpty($DestVhdName))
        {
            if ($DestVhdName -notlike "*.vhd")
            {
                $myDestBlobName = $($DestVhdName + ".vhd")
            }
            else
            {
                $myDestBlobName = $DestVhdName
            }
        }
        else
        {
            switch($PSCmdlet.ParameterSetName)
            {
                "CopyVhdFromLab"
                {
                    $myDestBlobName = $SrcDtlVhd.Name
                }

                "CopyVhdFromStorageContainer"
                {
                    $myDestBlobName = $SrcVhdBlobName
                }
            }
        }

        # Get a storage context associated with the destination lab's default storage account.
        Write-Verbose $("Extracting a storage acccount context for the lab '" + $DestLab.Name + "'")

        $myDestStorageContext = New-AzureRmDtlLabStorageContext -Lab $DestLab

        if ($null -eq $myDestStorageContext)
        {
            throw $("Unable to extract the storage account context for lab '" + $DestLab.Name + "'")
        }

        Write-Verbose $("Successfully extracted a storage account context for the lab '" + $DestLab.Name + "'")

        # Extract the 'uploads' container (which houses the vhds) from the destination lab.
        $myDestContainer = Get-AzureStorageContainer -Name "uploads" -Context $myDestStorageContext

        if ($null -eq $myDestContainer)
        {
            throw $("Unable to extract the 'uploads' container from the default storage account of lab '" + $DestLab.Name + "'")
        }

        $myDestContainerName = $myDestContainer.Name

        # Compute the destination vhd uri. 
        $myDestBlobUri = $($myDestContainer.CloudBlobContainer.Uri.AbsoluteUri + "/" + $myDestBlobName) 

        # check if the vhd with same name already exists in the destination lab.
        $myDestBlobExists = ($null -ne (Get-AzureStorageBlob -Blob $myDestBlobName -Container $myDestContainerName -Context $myDestStorageContext -ErrorAction Ignore))


        #
        # Section #2: Figure out that source storage details
        # 

        $mySrcBlobName = $null
        $mySrcContainer = $null
        $mySrcContainerName = $null
        $mySrcStorageContext = $null

        switch($PSCmdlet.ParameterSetName)
        {
            "CopyVhdFromLab"
            {
                # Pre-condition check to ensure that src vhd indeed belongs to the src lab.
                $srcVhd = Get-AzureRmDtlVhd -VhdAbsoluteUri $SrcDtlVhd.ICloudBlob.Uri.AbsoluteUri -Lab $SrcDtlLab

                if (($null -eq $srcVhd) -or ($srcVhd.ICloudBlob.Uri.AbsoluteUri -ne $SrcDtlVhd.ICloudBlob.Uri.AbsoluteUri))
                {
                    throw $("The specified vhd '" + $SrcDtlVhd.Name + "' could not be located in the lab '" + $SrcDtlLab.Name + "'.")
                }

                $mySrcBlobName = $SrcDtlVhd.Name

                # Create a new storage context for the src lab.
                Write-Verbose $("Extracting a storage account context for the lab '" + $SrcDtlLab.Name + "'")

                $mySrcStorageContext = New-AzureRmDtlLabStorageContext -Lab $SrcDtlLab

                if ($null -eq $mySrcStorageContext)
                {
                    throw $("Unable to create a new storage account context for the lab '" + $SrcDtlLab.Name + "'")
                }

                Write-Verbose $("Successfully extracted a storage account context for the lab '" + $SrcDtlLab.Name + "'")

                # Extract the 'uploads' container (which houses the vhds) from the src lab.
                $mySrcContainer = Get-AzureStorageContainer -Name "uploads" -Context $mySrcStorageContext

                if ($null -eq $mySrcContainer)
                {
                    throw $("Unable to extract the 'uploads' container from the default storage account of lab '" + $SrcDtlLab.Name + "'")
                }

                $mySrcContainerName = $mySrcContainer.Name
            }


            "CopyVhdFromStorageContainer"
            {
                $mySrcBlobName = $SrcVhdBlobName

                # Create a new storage context using the provided src storage account name and key.
                Write-Verbose $("Extracting a storage account context for the storage account '" + $SrcVhdStorageAccountName + "'")

                $mySrcStorageContext = New-AzureStorageContext -StorageAccountName $SrcVhdStorageAccountName -StorageAccountKey $SrcVhdStorageAccountKey

                if ($null -eq $mySrcStorageContext)
                {
                    throw $("Unable to create a new storage account context for storage account '" + $SrcVhdStorageAccountName + "'")
                }

                Write-Verbose $("Successfully extracted a storage account context for the storage account '" + $SrcVhdStorageAccountName + "'")

                # Extract the specified container (which houses the vhds) from the src lab.
                $mySrcContainer = Get-AzureStorageContainer -Name $SrcVhdContainerName -Context $mySrcStorageContext

                if ($null -eq $mySrcContainer)
                {
                    throw $("Unable to extract the container '" + $SrcVhdContainerName +"' from the storage account '" + $SrcVhdStorageAccountName + "'")
                }

                $mySrcContainerName = $mySrcContainer.Name
            }
        }


        #
        # Section #3: Copying vhd from source to destination
        #

        # Processing the -Confirm and -Whatif switches.
        if ($PSCmdlet.ShouldProcess($myDestBlobName, "Add Vhd"))
        {
            if ($myDestBlobExists -and ($false -eq $PSBoundParameters.ContainsKey("OverWrite")))
            {
                throw $("A vhd with the name '" + $myDestBlobName + "' already exists in the lab '" + $DestLab.Name + "'. Please use the -OverWrite switch to overwrite it.")
            }

            # copy the vhd to the lab.
            Write-Verbose $("Copying the vhd to lab '" + $DestLab.Name + "'")
            Write-Verbose $("Source blob: " + $mySrcBlobName)
            Write-Verbose $("Source container: " + $mySrcContainerName)
            Write-Verbose $("Source storage account: " + $mySrcStorageContext.StorageAccountName)
            Write-Verbose $("Destination blob: " + $myDestBlobName)
            Write-Verbose $("Destination container: " + $myDestContainerName)
            Write-Verbose $("Destination storage account: " + $myDestStorageContext.StorageAccountName)

            $partiallyCopiedVhd = Start-AzureStorageBlobCopy -SrcBlob $mySrcBlobName -SrcContainer $mySrcContainerName -Context $mySrcStorageContext -DestBlob $myDestBlobName -DestContainer $myDestContainerName -DestContext $myDestStorageContext -ConcurrentTaskCount $NumThreads -Force -ErrorAction "Stop"

            if ($false -eq $? -or $null -eq $partiallyCopiedVhd)
            {
                throw "An error occurred while copying the vhd to the lab '" + $DestLab.Name + "'."
            }    

            Write-Verbose $("Successfully initiated the copy of vhd '" + $mySrcBlobName + "' to lab '" + $DestLab.Name + "'.")

            if($PSBoundParameters.ContainsKey("WaitForCompletion"))
            {
                Write-Warning $("Waiting for the vhd copy operation to complete (Note: This can take a while)...")

                # let us measure the file copy time for instrumentation purposes.
                $stopWatch = [Diagnostics.Stopwatch]::StartNew()

                Get-AzureStorageBlobCopyState -Blob $myDestBlobName -Container $myDestContainerName -Context $myDestStorageContext -WaitForComplete | Out-Null

                if ($false -eq $?)
                {
                    throw "An error occurred while querying the copy-state of the uploaded vhd."
                }    

                $stopWatch.Stop()
                Write-Verbose $("Successfully copied vhd to lab " + $stopWatch.Elapsed.TotalSeconds + " seconds.")

                # fetch and return the vhd which was just uploaded
                Get-AzureRmDtlVhd -Lab $DestLab -VhdAbsoluteUri $myDestBlobUri | Write-Output
            }
            else
            {
                Write-Verbose $("The output is a vhd object which has been partially copied into the destination lab.")
                Write-Verbose $("To get the status of the vhd copy-operation, please use the 'New-AzureRmDtlLabStorageContext' and 'get-AzureStorageBlobCopyState' cmdlets.")
                Write-Verbose $("To see an example, please run 'Get-Help Start-AzureRmDtlVhdCopy -Examples'.")

                $partiallyCopiedVhd | Write-Output
            }
        }
    } 
}

##################################################################################################

function New-AzureRmDtlVirtualMachine
{
    <#
        .SYNOPSIS
        Creates a new virtual machine.

        .DESCRIPTION
        The New-AzureRmDtlVirtualMachine cmdlet creates a new VM in a lab (and optionally creates a user account on the VM).

        .EXAMPLE
        $lab = $null

        $lab = Get-AzureRmDtlLab -LabName "MyLab"
        $customimage = Get-AzureRmDtlCustomImage -Lab $lab -CustomImageName "MyCustomImage"
        New-AzureRmDtlVirtualMachine -VMName "MyVM" -VMSize "Standard_A4" -Lab $lab -Image $customimage

        Creates a new VM "MyVM" from the custom image "MyCustomImage" in the lab "MyLab".
        - No new user account is created during the VM creation.
        - We assume that the original custom image already contains a built-in user account.
        - We assume that this built-in account can be used to log into the VM after creation.

        .EXAMPLE
        $lab = $null

        $lab = Get-AzureRmDtlLab -LabName "MyLab"
        $customimage = Get-AzureRmDtlCustomImage -Lab $lab -CustomImageName "MyCustomImage"
        $secPwd = ConvertTo-SecureString -String "MyPwd" -AsPlainText -Force
        New-AzureRmDtlVirtualMachine -VMName "MyVM" -VMSize "Standard_A4" -Lab $lab -Image $customimage -UserName "MyAdmin" -Password $secPwd
        
        Creates a new VM "MyVM" from the custom image "MyCustomImage" in the lab "MyLab".
        - A new user account is created using the username/password combination specified.
        - This user account is added to the local administrators group. 

        .EXAMPLE
        $lab = $null

        $lab = Get-AzureRmDtlLab -LabName "MyLab"
        $galleryimage = Get-AzureRmDtlGalleryImage -Lab $lab -GalleryImageName "MyGalleryImage"
        $secPwd = ConvertTo-SecureString -String "MyPwd" -AsPlainText -Force
        New-AzureRmDtlVirtualMachine -VMName "MyVM" -VMSize "Standard_A4" -Lab $lab -Image $galleryimage -UserName "MyAdmin" -Password $secPwd

        Creates a new VM "MyVM" from the gallery image "MyGalleryImage" in the lab "MyLab".
        - A new user account is created using the username/password combination specified.
        - This user account is added to the local administrators group. 

        .EXAMPLE
        $lab = $null

        $lab = Get-AzureRmDtlLab -LabName "MyLab"
        $customimage = Get-AzureRmDtlCustomImage -Lab $lab -CustomImageName "MyCustomImage"
        $sshKey = ConvertTo-SecureString -String "MyKey" -AsPlainText -Force
        New-AzureRmDtlVirtualMachine -VMName "MyVM" -VMSize "Standard_A4" -Lab $lab -Image $customimage -UserName "MyAdmin" -SSHKey $sshKey
        
        Creates a new VM "MyVM" from the custom image "MyCustomImage" in the lab "MyLab".
        - A new user account is created using the username/SSH-key combination specified.

        .EXAMPLE
        $lab = $null

        $lab = Get-AzureRmDtlLab -LabName "MyLab"
        $galleryimage = Get-AzureRmDtlGalleryImage -Lab $lab -GalleryImageName "MyGalleryImage"
        $sshKey = ConvertTo-SecureString -String "MyKey" -AsPlainText -Force
        New-AzureRmDtlVirtualMachine -VMName "MyVM" -VMSize "Standard_A4" -Lab $lab -Image $galleryimage -UserName "MyAdmin" -SSHKey $sshKey

        Creates a new VM "MyVM" from the gallery image "MyGalleryImage" in the lab "MyLab".
        - A new user account is created using the username/SSH-key combination specified.

        .INPUTS
        None. Currently you cannot pipe objects to this cmdlet (this will be fixed in a future version).  
    #>
    [CmdletBinding(DefaultParameterSetName="BuiltInUser")]
    Param(
        [Parameter(Mandatory=$true, ParameterSetName="BuiltInUser")] 
        [Parameter(Mandatory=$true, ParameterSetName="UsernamePwd")] 
        [Parameter(Mandatory=$true, ParameterSetName="UsernameSSHKey")] 
        [ValidateNotNullOrEmpty()]
        [string]
        # The name of VM to be created.
        $VMName,

        [Parameter(Mandatory=$true, ParameterSetName="BuiltInUser")] 
        [Parameter(Mandatory=$true, ParameterSetName="UsernamePwd")] 
        [Parameter(Mandatory=$true, ParameterSetName="UsernameSSHKey")] 
        [ValidateNotNullOrEmpty()]
        [string]
        # The size of VM to be created ("Standard_A0", "Standard_D1_v2", "Standard_D2" etc).
        $VMSize,

        [Parameter(Mandatory=$true, ParameterSetName="BuiltInUser")] 
        [Parameter(Mandatory=$true, ParameterSetName="UsernamePwd")] 
        [Parameter(Mandatory=$true, ParameterSetName="UsernameSSHKey")] 
        [ValidateNotNull()]
        # An existing lab in which the VM will be created (please use the Get-AzureRmDtlLab cmdlet to get this lab object).
        $Lab,

        [Parameter(Mandatory=$true, ParameterSetName="BuiltInUser")] 
        [Parameter(Mandatory=$true, ParameterSetName="UsernamePwd")] 
        [Parameter(Mandatory=$true, ParameterSetName="UsernameSSHKey")] 
        [ValidateNotNull()]
        # An existing custom or gallery image which will be used to create the new VM (please use the Get-AzureRmDtlCustomImage or Get-AzureRmDtlGalleryImage cmdlets to get this image object).
        # Note: This custom image must exist in the lab identified via the '-LabName' parameter.
        $Image,

        [Parameter(Mandatory=$true, ParameterSetName="UsernamePwd")] 
        [Parameter(Mandatory=$true, ParameterSetName="UsernameSSHKey")] 
        [ValidateNotNullOrEmpty()]
        [string]
        # The user name that will be created on the new VM.
        $UserName,

        [Parameter(Mandatory=$true, ParameterSetName="UsernamePwd")] 
        [ValidateNotNullOrEmpty()]
        [Security.SecureString]
        # The password for the user to be created.
        $Password,

        [Parameter(Mandatory=$true, ParameterSetName="UsernameSSHKey")] 
        [ValidateNotNullOrEmpty()]
        [Security.SecureString]
        # The public SSH key for user to be created.
        $SSHKey
    )

    PROCESS 
    {
        Write-Verbose $("Processing cmdlet '" + $PSCmdlet.MyInvocation.InvocationName + "', ParameterSet = '" + $PSCmdlet.ParameterSetName + "'")

        # is this a gallery image?        
        $isGalleryImage = ($null -ne $Image.Properties -and $null -ne $Image.Properties.ImageReference)

        # Pre-condition checks for azure gallery images.
        if ($isGalleryImage)
        {
            if ($false -eq (($PSBoundParameters.ContainsKey("UserName") -and $PSBoundParameters.ContainsKey("Password")) -or ($PSBoundParameters.ContainsKey("UserName") -and $PSBoundParameters.ContainsKey("SSHKey"))))
            {
                throw $("You specified a gallery Image '" + $Image.Name + "'. Please specify either the -UserName and -Password parameters or the -UserName and -SSHKey parameters to use this gallery image.")
            }
        }
        else
        {
            # Get the same custom image object, but with properties attached.
            $Image = GetResourceWithProperties_Private -Resource $Image
            # Pre-condition checks for linux vhds.
            if ("linux" -eq $Image.Properties.OsType)
            {
                if ($false -eq (($PSBoundParameters.ContainsKey("UserName") -and $PSBoundParameters.ContainsKey("Password")) -or ($PSBoundParameters.ContainsKey("UserName") -and $PSBoundParameters.ContainsKey("SSHKey"))))
                {
                    throw $("The specified custom image '" + $Image.Name + "' uses a linux vhd. Please specify either the -UserName and -Password parameters or the -UserName and -SSHKey parameters to use this custom image.")
                }
            }

            # Pre-condition checks for windows vhds.
            else 
            {
                # Pre-condition checks for sysprepped Windows vhds.
                if ($true -eq $Image.Properties.Vhd.SysPrep)
                {
                    if ($false -eq ($PSBoundParameters.ContainsKey("UserName") -and $PSBoundParameters.ContainsKey("Password")))
                    {
                        throw $("The specified custom image '" + $Image.Name + "' uses a sysprepped vhd. Please specify both the -UserName and -Password parameters to use this custom image.")
                    }
                }

                # Pre-condition checks for non-sysprepped Windows vhds.
                # Note: For non-sysprepped windows vhds we ignore the username and password and instead use the built-in account.
                else
                {
                    if ($true -eq ($PSBoundParameters.ContainsKey("UserName") -and $PSBoundParameters.ContainsKey("Password")))
                    {
                        Write-Warning $("The specified custom image '" + $Image.Name + "' uses a non-sysprepped vhd with a built-in account. The specified userame and password will not be used.")
                    }                    
                }
            }
        }


        # Folder location of VM creation script, the template file and template parameters file.
        $VMCreationTemplateFile = $null

        switch($PSCmdlet.ParameterSetName)
        {
            "BuiltInUser"
            {
                $VMCreationTemplateFile = Join-Path $PSScriptRoot -ChildPath $ARMTemplate_CreateVM_BuiltinUsr -Resolve
            }

            "UsernamePwd"
            {
                if($isGalleryImage) 
                {
                    $VMCreationTemplateFile = Join-Path $PSScriptRoot -ChildPath $ARMTemplate_CreateVM_UsrPwd_GalleryImage -Resolve
                } else 
                {
                    $VMCreationTemplateFile = Join-Path $PSScriptRoot -ChildPath $ARMTemplate_CreateVM_UsrPwd_CustomImage -Resolve
                }
            }

            "UsernameSSHKey"
            {
                if($isGalleryImage) 
                {
                    $VMCreationTemplateFile = Join-Path $PSScriptRoot -ChildPath $ARMTemplate_CreateVM_UsrSSH_GalleryImage -Resolve
                } else 
                {
                    $VMCreationTemplateFile = Join-Path $PSScriptRoot -ChildPath $ARMTemplate_CreateVM_UsrSSH_CustomImage -Resolve
                }
            }
        }

        # pre-condition check to ensure that the template file actually exists.
        if ($false -eq (Test-Path -Path $VMCreationTemplateFile))
        {
            Write-Error $("The RM template file could not be located at : '" + $VMCreationTemplateFile + "'")
        }
        else
        {
            Write-Verbose $("The RM template file was located at : '" + $VMCreationTemplateFile + "'")
        }


        # Create the virtual machine in this lab by deploying the RM template
        Write-Warning $("Creating new virtual machine '" + $VMName + "'. This may take a couple of minutes.")

        $rgDeployment = $null

        # Unique name for the deployment
        $deploymentName = [Guid]::NewGuid().ToString()

        switch($PSCmdlet.ParameterSetName)
        {
            "BuiltInUser"
            {
                $rgDeployment = New-AzureRmResourceGroupDeployment -Name $deploymentName -ResourceGroupName $Lab.ResourceGroupName -TemplateFile $VMCreationTemplateFile -newVMName $VMName -existingLabName $Lab.ResourceName -newVMSize $VMSize -existingCustomImageName $Image.Name -ErrorAction "Stop"
            }

            "UsernamePwd"
            {
                if($isGalleryImage) 
                {
                    $rgDeployment = New-AzureRmResourceGroupDeployment -Name $deploymentName -ResourceGroupName $Lab.ResourceGroupName -TemplateFile $VMCreationTemplateFile -newVMName $VMName -existingLabName $Lab.ResourceName -newVMSize $VMSize -userName $UserName -password $Password -Offer $Image.Properties.ImageReference.Offer -Sku $Image.Properties.ImageReference.Sku -Publisher $Image.Properties.ImageReference.Publisher -Version $Image.Properties.ImageReference.Version -OsType $Image.Properties.ImageReference.OsType -ErrorAction "Stop"
                }
                else 
                {                
                    $rgDeployment = New-AzureRmResourceGroupDeployment -Name $deploymentName -ResourceGroupName $Lab.ResourceGroupName -TemplateFile $VMCreationTemplateFile -newVMName $VMName -existingLabName $Lab.ResourceName -newVMSize $VMSize -existingCustomImageName $Image.Name -userName $UserName -password $Password -ErrorAction "Stop"
                }
            }

            "UsernameSSHKey"
            {
                if($isGalleryImage) 
                {
                    $rgDeployment = New-AzureRmResourceGroupDeployment -Name $deploymentName -ResourceGroupName $Lab.ResourceGroupName -TemplateFile $VMCreationTemplateFile -newVMName $VMName -existingLabName $Lab.ResourceName -newVMSize $VMSize -userName $UserName -sshKey $SSHKey -Offer $Image.Properties.ImageReference.Offer -Sku $Image.Properties.ImageReference.Sku -Publisher $Image.Properties.ImageReference.Publisher -Version $Image.Properties.ImageReference.Version -OsType $Image.Properties.ImageReference.OsType -ErrorAction "Stop"
                }
                else 
                { 
                    $rgDeployment = New-AzureRmResourceGroupDeployment -Name $deploymentName -ResourceGroupName $Lab.ResourceGroupName -TemplateFile $VMCreationTemplateFile -newVMName $VMName -existingLabName $Lab.ResourceName -newVMSize $VMSize -existingCustomImageName $Image.Name -userName $UserName -sshKey $SSHKey -ErrorAction "Stop" 
                }
            }
        }

        if (($null -ne $rgDeployment) -and ($null -ne $rgDeployment.Outputs['vmId']) -and ($null -ne $rgDeployment.Outputs['vmId'].Value))
        {
            Write-Verbose $("vm id : '" + $rgDeployment.Outputs['vmId'].Value + "'")

            Get-AzureRmResource -ResourceId $rgDeployment.Outputs['vmId'].Value | Write-Output
        }
    }
}

##################################################################################################

function Remove-AzureRmDtlVirtualMachine
{
    <#
        .SYNOPSIS
        Deletes specified virtual machines.

        .DESCRIPTION
        The Remove-AzureRmDtlVirtualMachine cmdlet does the following: 
        - Deletes a specific VM, if the -VMId parameter is specified.
        - Deletes all VMs in a lab, if the -LabName parameter is specified.

        Warning: 
        - If multiple VMs match the specified conditions, all of them will be deleted. 
        - Please use the '-WhatIf' parameter to preview the VMs being deleted (without actually deleting them).
        - Please use the '-Confirm' parameter to pop up a confirmation dialog for each VM to be deleted.

        .EXAMPLE
        Remove-AzureRmDtlVirtualMachine -VMId "/subscriptions/xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx/resourceGroups/MyLabRG/providers/Microsoft.DevTestLab/environments/MyVM"
        Deletes a specific VM, identified by the specified resource-id.

        .EXAMPLE
        Remove-AzureRmDtlVirtualMachine -VMName "MyVM1"
        Deletes all VMs with the name "MyVM1".

        .EXAMPLE
        Remove-AzureRmDtlVirtualMachine -LabName "MyLab" -VMName "MyVM1"
        Deletes Vm "MyVM1" within the lab "MyLab".

        .INPUTS
        None. Currently you cannot pipe objects to this cmdlet (this will be fixed in a future version).  
    #>
    [CmdletBinding(
        SupportsShouldProcess=$true)]
    Param(
        [Parameter(Mandatory=$true, ParameterSetName="DeleteByVMId")] 
        [ValidateNotNullOrEmpty()]
        [string]
        # The ResourceId of the VM (e.g. "/subscriptions/xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx/resourceGroups/MyLabRG/providers/Microsoft.DevTestLab/labs/MyLab/environments/MyVM").
        $VMId,

        [Parameter(Mandatory=$true, ParameterSetName="DeleteInLab")] 
        [ValidateNotNull()]
        # An existing lab (please use the Get-AzureRmDtlLab cmdlet to get this lab object).
        $Lab,

        [Parameter(Mandatory=$false, ParameterSetName="DeleteInLab")] 
        [ValidateNotNullOrEmpty()]
        [string]
        # The name of the VM.
        $VMName
    )

    PROCESS
    {
        Write-Verbose $("Processing cmdlet '" + $PSCmdlet.MyInvocation.InvocationName + "', ParameterSet = '" + $PSCmdlet.ParameterSetName + "'")

        $vms = $null

        # First step is to fetch the specified VMs.
        switch($PSCmdlet.ParameterSetName)
        {
            "DeleteByVMId"
            {
                $vms = Get-AzureRmDtlVirtualMachine -VMId $VMId
            } 

            "DeleteInLab"
            {
                if ($PSBoundParameters.ContainsKey("VMName"))
                {
                    $vms = Get-AzureRmDtlVirtualMachine -Lab $Lab -VmName $VMName 
                }
                else
                {
                    $vms = Get-AzureRmDtlVirtualMachine -Lab $Lab
                }
            }            
        }

        # Next, for each VM... 
        foreach ($vm in $vms)
        {
            # Pop the confirmation dialog.
            if ($PSCmdlet.ShouldProcess($vm.Name, "delete VM"))
            {
                Write-Warning $("Deleting VM '" + $vm.Name + "' (Id = " + $vm.ResourceId + ") ...")
                Write-Verbose $("Deleting VM '" + $vm.Name + "' (Id = " + $vm.ResourceId + ") ...")

                # Nuke the VM.
                $result = Remove-AzureRmResource -ResourceId $vm.ResourceId -Force

                if ($true -eq $result)
                {
                    Write-Verbose $("Successfully deleted VM '" + $vm.ResourceName + "' (Id = " + $vm.ResourceId + ") ...")
                }
            }
        }
    }
}

##################################################################################################
