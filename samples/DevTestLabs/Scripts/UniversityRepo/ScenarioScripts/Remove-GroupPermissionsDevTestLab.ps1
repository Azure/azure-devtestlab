<#
.SYNOPSIS 
    This script removes the specified role from the AD Group in the DevTest Lab.

.DESCRIPTION
    This script allows IT admins to remove programmatically the permissions to access lab resources to a specific group associated to a specific role.

.PARAMETER labName
    Mandatory. The name of the lab.

.PARAMETER ADGroupName
    Mandatory. The name of the AD group.

.PARAMETER role
    Optional. The role definition name. 
    Default "University DevTest Labs User".

.PARAMETER profilePath
    Optional. Path to file with Azure Profile. How to generate this file is explained at the end of the Readme for the repo (https://github.com/lucabol/University).
    Default "$env:APPDATA\AzProfile.txt".

.EXAMPLE
    Remove-GroupPermissionsDevTestLab -labName University -ADGroupName MyGroup

.EXAMPLE
    Remove-GroupPermissionsDevTestLab -labName University -ADGroupName MyGroup -role "My DevTest Lab User"

.NOTES

#>
[cmdletbinding()]
param 
(
    [Parameter(Mandatory = $true, HelpMessage = "The name of the lab")]
    [string] $labName,
    
    [Parameter(Mandatory = $true, HelpMessage = "The name of the AD group")]
    [string] $ADGroupName,

    [Parameter(Mandatory = $false, HelpMessage = "The role definition name")]
    [string] $role = "University DevTest Labs User",

    [Parameter(Mandatory = $false, HelpMessage = "Path to file with Azure Profile")]
    [string] $profilePath = "$env:APPDATA\AzProfile.txt"
)

trap {
    # NOTE: This trap will handle all errors. There should be no need to use a catch below in this
    #       script, unless you want to ignore a specific error.
    Handle-LastError
}

. .\Common.ps1

$credentialsKind = InferCredentials
LogOutput "Credentials kind: $credentialsKind"

LoadAzureCredentials -credentialsKind $credentialsKind -profilePath $profilePath

$azVer = GetAzureModuleVersion
if ($azVer -ge "3.8.0") {
    $SubscriptionID = (Get-AzureRmContext).Subscription.Id
}
else {
    $SubscriptionID = (Get-AzureRmContext).Subscription.SubscriptionId
}

$ResourceGroupName = (Find-AzureRmResource -ResourceType "Microsoft.DevTestLab/labs" -ResourceNameContains $LabName).ResourceGroupName

# get the ObjectId from the AD group name
$objectId = Get-AzureRmADGroup -SearchString $ADGroupName

# remove the role from the group for the specified lab
Remove-AzureRmRoleAssignment -ObjectId $objectId.Id -Scope /subscriptions/$SubscriptionID/resourcegroups/$ResourceGroupName/providers/microsoft.devtestlab/labs/$labName -RoleDefinitionName $role
