[CmdletBinding()]
param(
    [parameter(Mandatory = $false)]
    [string]$Email,

    [parameter(Mandatory = $false, HelpMessage = "Default username for all VMs")]
    [string]$Username = "AdminUser",

    [parameter(Mandatory = $false, HelpMessage = "Default password for all VMs")]
    [string]$Password = "P@ssword1!",

    [parameter(Mandatory = $false, HelpMessage = "Default location for lab account")]
    [string]$Location = "centralus",

    [parameter(Mandatory = $false, HelpMessage = "Default location for lab account")]
    [string]$ClassName = "EthicalHacking"
)

###################################################################################################
#
# Handle all errors in this script.
#

trap {
    # NOTE: This trap will handle all errors. There should be no need to use a catch below in this
    #       script, unless you want to ignore a specific error.
    $message = $Error[0].Exception.Message
    if ($message) {
        Write-Host -Object "`nERROR: $message" -ForegroundColor Red
    }

    Write-Host "`nThe script failed to run.`n"

    # IMPORTANT NOTE: Throwing a terminating error (using $ErrorActionPreference = "Stop") still
    # returns exit code zero from the PowerShell script when using -File. The workaround is to
    # NOT use -File when calling this script and leverage the try-catch-finally block and return
    # a non-zero exit code from the catch block.
    exit -1
}

###################################################################################################
#
# Main execution block.
#

# Download AzLab module file, import, and then delete the file
Invoke-WebRequest "https://raw.githubusercontent.com/Azure/azure-devtestlab/master/samples/ClassroomLabs/Modules/Library/Az.LabServices.psm1" -OutFile Az.LabServices.psm1
Import-Module .\Az.LabServices.psm1 -Force
Remove-Item .\Az.LabServices.psm1

# Configure parameter names
$rgName     = "$($ClassName)RG_" + (Get-Random)
$labAcctName     = "$($ClassName)Acct_" + (Get-Random)
$labName    =  "$($ClassName)Lab"

# Create resource group
Write-Host "Creating resource group $rgName"
$rg = New-AzResourceGroup -Name $rgName -Location $Location
    
# Create Lab Account
Write-Host "Creating lab account $labAcctName"
$labAcct  = New-AzLabAccount -ResourceGroupName $rgName -LabAccountName $labAcctName

# Ensure that image needed for the VM is available
$imageName = "Windows Server 2019 Datacenter"
Write-Host "Locating '$imageName' image for use in template virtual machine"
$imageObject = $labAcct | Get-AzLabAccountGalleryImage | Where-Object -Property Name -EQ $imageName

if($null -eq $imageObject) {
    Write-Error "Image '$imageName' was not found in the gallery images. No lab was created within lab account $labAcctName."
    exit -1
}

# Create lab on the lab account
Write-Host "Creating $labName with '$($imageObject.Name)' image"
Write-Warning "  Warning: Creating template vm may take up to 20 minutes."
$lab = $labAcct | New-AzLab -LabName $labName -UserName $Username -Password $Password -SharedPasswordEnabled -UsageQuotaInHours 10 -Size "Virtualization" -Image $imageObject

# If lab created, perform next configuration
if($null -eq $lab) {
    Write-Error "Lab failed to create."
    exit -1
}

Write-Host "Lab has been created."

# Stop the VM image so that it is not costing the end user
Write-Host "Stopping the template VM within $labName"
Write-Warning "  Warning: This could take some time to stop the template VM."
$labTemplateVM = Get-AzLabTemplateVM $lab
Stop-AzLabTemplateVm $labTemplateVM

# Give permissions to optional email address user
if ($Email) 
{
    #grant access to labs if an educator email address was provided
    Write-Host "Retrieving user data for $Email"
    $userId = Get-AzADUser -UserPrincipalName $Email | Select-Object -expand Id

    if($null -eq $userId) {
        Write-Warning "$Email is NOT an user in your AAD. Could not add permissions for this user to the lab account and lab."
    }
    else
    {
        Write-Host "Adding $Email as a Reader to the lab account"
        New-AzRoleAssignment -ObjectId $userId -RoleDefinitionName 'Reader' -ResourceGroupName $rg.ResourceGroupName -ResourceName $labAcct.Name -ResourceType $labAcct.Type
        Write-Host "Adding $Email as a Contributor to the lab"
        New-AzRoleAssignment -ObjectId $userId -RoleDefinitionName 'Contributor' -Scope $lab.id
    }
}

Write-Host "Done!" -ForegroundColor 'Green'