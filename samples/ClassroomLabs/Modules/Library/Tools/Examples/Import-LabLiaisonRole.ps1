[CmdletBinding()]
param(
    [parameter(Mandatory = $false, ValueFromPipelineByPropertyName = $true)]
    [string[]] $SubscriptionIds = @(),

    [parameter(Mandatory = $false, ValueFromPipelineByPropertyName = $true)]
    [string] $RoleDefinitionName = "Lab Services Liaison"
)

#Requires -Modules Az.Accounts, Az.Resources

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

#Verify role not already imported
$role = Get-AzRoleDefinition -Name $RoleDefinitionName -ErrorAction SilentlyContinue
$foundRole = $null -ne $role 
if ($foundRole) {
    Write-Verbose "Role $RoleDefinitionName found.  Existing role will be updated."
}else{
    $role = New-Object -TypeName 'Microsoft.Azure.Commands.Resources.Models.Authorization.PSRoleDefinition'
    $role.Id = $null
    $role.Name = $RoleDefinitionName
    $role.Description = "Can view labs in Azure Lab portal and reset student VMs."
    $role.IsCustom = $true
    $role.Actions = @()
    $role.AssignableScopes = @()
}

#Get current subscription, if one is not specified
if (-not $SubscriptionIds -or (($SubscriptionIds | Measure-Object).Count -eq 0)){
    $currentSubscriptionId = Get-AzContext | Select-Object -expand Subscription | Select-Object -expand Id
    if (-not $currentSubscriptionId){
        Write-Error "SubscriptionIds not specified and unable to get subscription id from current context."
    }else {
        $SubscriptionIds = @($currentSubscriptionId)
    }
}

#Add suscriptions to the scope of the role definition, if needed
$SubscriptionIds | 
ForEach-Object {
    if ($role.AssignableScopes -notcontains "/subscriptions/$_") {
        $role.AssignableScopes.Add("/subscriptions/$_")
    }
}

$roleAssignmentsToAdd = @(
"Microsoft.LabServices/*/read", 
"Microsoft.LabServices/labAccounts/labs/environmentSettings/environments/delete",
#Must add these actions for 'My Labs' page to show
"Microsoft.LabServices/labAccounts/labs/write",
"Microsoft.LabServices/labaccounts/getRestrictionsAndUsage/action",
"Microsoft.LabServices/labaccounts/getPricingAndAvailability/action"
)

#Add needed role assignments, if not already included in role definition
$roleAssignmentsToAdd | 
ForEach-Object {
    if ($role.Actions -notcontains $_){
        $role.Actions.Add($_)
    }
}

if ($foundRole){
    $result = Set-AzRoleDefinition -Role $role
    Write-Output "Role definition $($role.Name) updated.  Remember, there is a delay between creation of a role definition and the ability to see the definition."
}
else{
    $result = New-AzRoleDefinition -Role $role
    Write-Output "Role definition $($role.Name) created.  Remember, there is a delay between creation of a role definition and the ability to see the definition."
}