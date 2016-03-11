<#  
    A simple test to ensure that DTL "GET" operations are functional. 
    This test fetches: 
    - An existing lab
    - An existing VM from that lab
    - An existing gallery image from that lab
#>

Describe "Testing GET Verbs" {

    # Existing assets in PROD. 
    $existingLabName = "DTL-RegressionTest-Lab"
    $existingGalleryImageName = "Windows Server 2012 R2 DataCenter"
    $existingVMName = "RegrTestVM1"

    # Fetch an existing lab.
    $lab = Get-AzureRmDtlLab -LabName $existingLabName -ShowProperties -Verbose 

    # Asserts / post-condition checks
    It "Get Lab" {
        $lab | Should Not BeNullOrEmpty
        $lab.Properties | Should Not BeNullOrEmpty
        $lab.Name | Should Be $existingLabName
        $lab.Properties.ProvisioningState | Should Be "succeeded"
    }

    # Fetch an existing lab VM.
    $vm = Get-AzureRmDtlVirtualMachine -Lab $lab -VMName $existingVMName -ShowProperties -Verbose

    # Asserts / post-condition checks
    It "Get VM" {
        $vm | Should Not BeNullOrEmpty
        $vm.Properties | Should Not BeNullOrEmpty
        $vm.Name | Should Be $existingVMName
        $vm.Properties.ProvisioningState | Should Be "succeeded"
    }

    # Fetch an existing gallery image from the lab.
    $galleryImage = Get-AzureRmDtlGalleryImage -GalleryImageName $existingGalleryImageName -Lab $lab -ShowProperties -Verbose 

    # Asserts / post-condition checks
    It "Get Gallery Image" {
        $galleryImage | Should Not BeNullOrEmpty
        $galleryImage.Properties | Should Not BeNullOrEmpty
        $galleryImage.Name | Should Be $existingGalleryImageName
        $galleryImage.Properties.ProvisioningState | Should Be "succeeded"
        $galleryImage.Properties.Enabled | Should Be $true
    }
}


<#  
    A test to ensure that DTL "POST" and "DELETE" operations are functional. 
    This test fetches: 
    - Creates a new lab
    - Creates a new VM in that lab (using an existing gallery image).
    - Saves the VM to a new custom image.
    - Deletes the VM.
    - Deletes the lab.
#>

Describe "Testing NEW Verbs" {

    # Create a new lab.
    $newLabName = $("RegrLab" + (Get-Random -Maximum 9999))
    $newLabLocation = "east us"
    $newLab = New-AzureRmDtlLab -LabName $newLabName -LabLocation $newLabLocation -Verbose

    # Asserts / post-condition checks
    It "New Lab" {
        $newLab | Should Not BeNullOrEmpty
        $newLab.Properties | Should Not BeNullOrEmpty
        $newLab.Name | Should Be $newLabName
        $newLab.Properties.ProvisioningState | Should Be "succeeded"
    }
    
    # Create a new lab VM using an existing gallery image.
    $existingGalleryImageName = "Windows Server 2012 R2 DataCenter"
    $existingGalleryImage = Get-AzureRmDtlGalleryImage -GalleryImageName $existingGalleryImageName -Lab $newLab -Verbose
    $newVMName = $("RegrVM" + (Get-Random -Maximum 9999))
    $newVMSize = "Standard_A0"
    $newVMUserName = "SomeAdmin"
    $newVMPassword = ConvertTo-SecureString -String "SomePassword!" -AsPlainText -Force 
    $newVM = New-AzureRmDtlVirtualMachine -VMName $newVMName -VMSize $newVMSize -Lab $newLab -Image $existingGalleryImage -Verbose -UserName $newVMUserName -Password $newVMPassword

    # Asserts / post-condition checks
    It "New VM" {
        $newVM | Should Not BeNullOrEmpty
        $newVM.Properties | Should Not BeNullOrEmpty
        $newVM.Name | Should Be $newVMName       
        $newVM.Properties.ProvisioningState | Should Be "succeeded"
        $newVM.Properties.Fqdn | Should Be "$newVMName.eastus.cloudapp.azure.com"
        $newVM.Properties.Size | Should Be $newVMSize
        $newVM.Properties.UserName | Should Be $newVMUserName
        $newVM.Properties.GalleryImageReference.Sku | Should Be "2012-R2-Datacenter"
    }

    # Save the new VM to a VM template.
    $newCustomImageName = $("RegrVMTemplate" + (Get-Random -Maximum 9999))
    $newCustomImageDescription = "VM Template created for regression testing. Please delete after use."
    $newCustomImage = New-AzureRmDtlCustomImage -SrcDtlVM $newVM -windowsOsState "SysprepApplied" -DestCustomImageName $newCustomImageName -DestCustomImageDescription $newCustomImageDescription -Verbose
    
    # Asserts / post-condition checks
    It "New VM Template" {
        $newCustomImage | Should Not BeNullOrEmpty
        $newCustomImage.Properties | Should Not BeNullOrEmpty
        $newCustomImage.Name | Should Be $newCustomImageName
        $newCustomImage.Properties.ProvisioningState | Should Be "succeeded"
        $newCustomImage.Properties.Vhd | Should Not BeNullOrEmpty
        $newCustomImage.Properties.Vhd.SysPrep | Should Be $true
    }

    # Delete the VM
    Remove-AzureRmDtlVirtualMachine -VMId $newVM.ResourceId -Verbose 

    # Asserts / post-condition checks
    It "Remove VM" {
        Get-AzureRmDtlVirtualMachine -VMId $newVM.ResourceId -ShowProperties -Verbose | Should BeNullOrEmpty
    }

    # Delete the Lab
    # @TODO: Assuming an empty lab (i.e. No VMs in it), what would be the recommended approach to completely nuke the lab? 
    # 1. Delete the lab itself (by calling Remove-AzureRmResource). Will this nuke the storage accounts associated with the lab?
    # 2.Delete the lab’s resource group itself (by calling Remove-AzureRmResourceGroup)    
}