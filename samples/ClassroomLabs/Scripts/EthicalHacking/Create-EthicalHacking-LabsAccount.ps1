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

Import-Module ..\..\Modules\Library\Az.LabServices.psm1
 
$rgName     = "$($ClassName)RG_" + (Get-Random)
$labAcctName     = "$($ClassName)Acct_" + (Get-Random)
$labName    =  "$($ClassName)Lab"

Write-Host "Creating resource group $rgName"
$rg = New-AzResourceGroup -Name $rgName -Location $Location
 
Write-Host "Creating lab account $labAcctName"
$labAcct  = New-AzLabAccount -ResourceGroupName $rgName -LabAccountName $labAcctName

$imageName = "Windows Server 2019 Datacenter"
Write-Host "Locating '$imageName' image for use in template virtual machine"
$imageObject = $labAcct | Get-AzLabAccountGalleryImage | Where-Object -Property Name -EQ $imageName
 
if($imageObject) {

    Write-Host "Creating lab $labName with '$($imageObject.Name)' image"
    Write-Host "  Warning: Creating template vm may take up to 20 minutes." -ForegroundColor 'Yellow'
    $lab = $labAcct | New-AzLab -LabName $labName -UserName $Username -Password $Password -SharedPasswordEnabled -UsageQuotaInHours 10 -Size "Virtualization" -Image $imageObject
    Write-Host "  Default credentials for VM is '$Username' for the username and '$Password' for the password." -ForegroundColor 'Yellow'

    Write-Host "Stop the template VM within $labName"
    $labTemplateVM = Get-AzLabTemplateVM $lab
    Stop-AzLabTemplateVm $labTemplateVM

    if ($Email) 
    {
        #grant access to labs if an educator email address was provided
        Write-Host "Adding $Email access to lab $labName"
        $userId = Get-AzADUser -UserPrincipalName $Email | Select-Object -expand Id
        if($userId)
        {
            New-AzRoleAssignment -ObjectId $userId -RoleDefinitionName 'Reader' -ResourceGroupName $rg.ResourceGroupName -ResourceName $labAcct.Name -ResourceType $labAcct.Type
            Write-Host "Added $Email as a Reader to the lab account"
            New-AzRoleAssignment -ObjectId $userId -RoleDefinitionName 'Contributor' -ResourceGroupName $rg.ResourceGroupName -ResourceName $lab.Name -ResourceType $lab.Type
            Write-Host "Added $Email as a Contributor to the lab"
        }
        else
        {
            Write-Host "$Email is NOT an user in your AAD" -ForegroundColor 'Red'
        }
    }

    Write-Host "Lab created!" -ForegroundColor 'Green'
} 
else {
    Write-Host "Image '$imageName' was not found in the gallery images. No lab was created within lab account $labAcctName." -ForegroundColor 'Red'
}