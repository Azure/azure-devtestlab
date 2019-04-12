# Create a new DevTest Lab formula

<a href="https://portal.azure.com/#create/Microsoft.Template/uri/https%3A%2F%2Fraw.githubusercontent.com%2FAzure%2Fazure-devtestlab%2Fmaster%2FSamples%2F201-dtl-create-formula%2Fazuredeploy.json" target="_blank">
    <img src="http://azuredeploy.net/deploybutton.png"/>
</a>


This template creates a new formula for an existing DevTestLab instance.

The template creates a formula that 
- Sets the Windows VM from an Azure MarketPlace image with size, publisher and sku as specified by the parameters.
- Sets the Windows VM to use the default virtual network and subnet for the DevTest Lab.
- Adds following artifacts to be installed a from the public artifact repository provided by DevTest Labs.  Artifact Ids are in the form {artifactRepositoryName}/{folderForAllArtifacts}/{artifactFolder}.
  - VSCode.  Backing code is at https://github.com/Azure/azure-devtestlab/tree/master/Artifacts/windows-vscode.  Artifact Id is `public repo/artifacts/windows-vscode`.
  - Enable Local Admins.  Backing code is at https://github.com/Azure/azure-devtestlab/tree/master/Artifacts/windows-enable-local-admins.  Artifact Id is `public repo/artifacts/windows-enable-local-admins`.

As noted earlier, this template works with a Windows image in Azure MarketPlace.  Formulas require different properties based on what the base is used.  See the instructions below for a method to discover which properties need to be supplied for your formula.

1. Using the Azure Portal, create a formula in the lab and save.
2. Click the '+  Virtual Machine' on the Overview blade of the lab and choose the formula created in the previous step.
3. Click the 'View ARM template' section at the bottom of the VM creation blade.
4. Adjust the artifactId and labVirtualNetworkId properties to be relative to the lab, rather than the full path. i.e. in the format of `"[concat('/artifactsources/', variables('repositoryName'), '/', variables('artifactsFolder'), '/', variables('artifactName'))]"`.
5. For custom images, use the property `"customImageId": "[concat('/customimages/', variable('imageName'))"`, instead of the full path of custom image ID.
6. Add json for creating the formula to your ARM template and deploy to labs as necessary.
