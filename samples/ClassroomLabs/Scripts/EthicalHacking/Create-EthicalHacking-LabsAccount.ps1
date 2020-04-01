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

# Install AzLab module
Import-Module ..\..\Modules\Library\Az.LabServices.psm1 -Force

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
  
# Only create lab if image type is found
if($imageObject) {

    # Create lab on the lab account
    Write-Host "Creating $labName with '$($imageObject.Name)' image"
    Write-Host "  Warning: Creating template vm may take up to 20 minutes." -ForegroundColor 'Yellow'
    $lab = $labAcct | New-AzLab -LabName $labName -UserName $Username -Password $Password -SharedPasswordEnabled -UsageQuotaInHours 10 -Size "Virtualization" -Image $imageObject
    Write-Host "Lab has been created. Credentials for VM template are '$Username' for the username and '$Password' for the password."

    # If lab created, perform next configuration
    if($lab) {

        # Stop the VM image so that it is not costing the end user
        Write-Host "Stop the template VM within $labName"
        $labTemplateVM = Get-AzLabTemplateVM $lab
        Stop-AzLabTemplateVm $labTemplateVM

        # Give permissions to optional email address user
        if ($Email) 
        {
            #grant access to labs if an educator email address was provided
            Write-Host "Adding $Email access to lab $labName"
            $userId = Get-AzADUser -UserPrincipalName $Email | Select-Object -expand Id
            if($userId)
            {
                Write-Host "Adding $Email as a Reader to the lab account"
                New-AzRoleAssignment -ObjectId $userId -RoleDefinitionName 'Reader' -ResourceGroupName $rg.ResourceGroupName -ResourceName $labAcct.Name -ResourceType $labAcct.Type
                Write-Host "Adding $Email as a Contributor to the lab"
                New-AzRoleAssignment -ObjectId $userId -RoleDefinitionName 'Contributor' -Scope $lab.id
            }
            else
            {
                Write-Host "$Email is NOT an user in your AAD" -ForegroundColor 'Red'
            }
        }
        
        Write-Host "Lab created!" -ForegroundColor 'Green'
    }
    else {
        Write-Host "Lab failed to create." -ForegroundColor 'Red'
    }
} 
else {
    Write-Host "Image '$imageName' was not found in the gallery images. No lab was created within lab account $labAcctName." -ForegroundColor 'Red'
} 