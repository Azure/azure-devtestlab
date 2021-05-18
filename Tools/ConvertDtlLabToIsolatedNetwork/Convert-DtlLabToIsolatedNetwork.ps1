<#
.Synopsis
    Script to convert an existing lab and associated lab resources to an isolated network mode.
.DESCRIPTION
    There currently exists an option to create a new lab in an isolated network mode. 
    This is done by selecting the "Network Isolation" option on the "Networking" tab during
    the 'create new lab' flow. However, there is no current method via the UX to modify an existing lab
    to an isolated network mode by modifying all the required objects needed to do so at once.
    This script does that by modifying all the required resources for a given lab. 
   
    Overview of the Steps:

    1. Configure Lab to use a SystemAssigned identity. All newer labs are created with this automatically, but
    older labs won't be. If creating a new SystemAssigned identity, we grant the various permissions onto 
    the keyvaults and storage accounts that it will need. 
    
    2. Update each user KeyVaults network settings. 
    Grant SystemAssigned identity RBAC permission - Secrets.
    Network Settings: Disable public network access, enable `Allow trusted Microsoft services to bypass this firewall.`
 
    3. Update each Storage Account network settings.
    Grant SystemAssigned identity RBAC permission - Blob Storage Contributor
    Configure Network Settings: Disable public network access, enable `Allow trusted Microsoft services to access this storage account.`
    Add Lab VNET(s) to the Storage Account.
    Add a ServiceEndpoint to VNET subnets. This allows outbound traffic to non-public endpoints.
 
    4. Update Lab: Set resourceNetworkIsolation = 'Enabled'


   Author: Arber Hila (ahila) - DevDiv - Lab Services
.PARAMETER SubsriptionId
    The SubscriptionId of which the lab is hosted in.
.PARAMETER LabRg
    The resource group of which the lab is hosted in.
.PARAMETER LabName
    Name of the lab that will be updated.
.EXAMPLE
   ./Convert-DtlLabToIsolatedNetwork.ps1 -SubscriptionId '123a5b78-1234-1234-1234-1234a56b89df' -LabRg 'my-resource-group' -LabName 'my-lab'
#>

[CmdletBinding()]
Param(
    [Parameter(Mandatory)]  
    [string] $SubscriptionId,

    [Parameter(Mandatory)]  
    [string] $LabRg,

    [Parameter(Mandatory)]  
    [string] $LabName
)

Function Get-NameFromResourceId {

    param ($ResourceId)

    $Name = $ResourceId -replace '.*\/'
    Write-Output $Name
}

Function Get-LabObject {
    
    $getParams = @{
        Method               = 'GET'
        ResourceGroupName    = $LabRg
        ResourceProviderName = 'Microsoft.DevTestLab'
        ResourceType         = 'labs'
        Name                 = $LabName
        ApiVersion           = '2018-10-15-preview'
    }
    
    $lab = Invoke-AzRestMethod @getParams
    
    Return $lab.content | ConvertFrom-Json
}

Function Set-LabObject {
    
    param (
        [string] $Payload
    )
    
    Return Invoke-AzRestMethod -Payload $Payload `
        -Method 'PUT' `
        -ResourceGroupName $LabRg `
        -ResourceProviderName 'Microsoft.DevTestLab' `
        -ResourceType 'labs' `
        -Name $LabName `
        -ApiVersion '2018-10-15-preview' | Out-Null
}

Function Get-AllLabUsers {
    
    $getParams = @{
        Method               = 'GET'
        ResourceGroupName    = $LabRg
        ResourceProviderName = 'Microsoft.DevTestLab'
        ResourceType         = "labs/$LabName/users"
        ApiVersion           = '2018-10-15-preview'
    }
    
    $users = Invoke-AzRestMethod @getParams
    
    Return $users.content | ConvertFrom-Json
}

Function Get-AllLabVnets {
    
    $getParams = @{
        Method               = 'GET'
        ResourceGroupName    = $LabRg
        ResourceProviderName = 'Microsoft.DevTestLab'
        ResourceType         = "labs/$LabName/virtualnetworks"
        ApiVersion           = '2018-10-15-preview'
    }
    
    $users = Invoke-AzRestMethod @getParams
    
    Return $users.content | ConvertFrom-Json
}

Function Edit-SystemAssignedIdentityKeyVaultPermissions {
    
    Param(
        [string] $KeyVaultName,
        [string] $ObjectId
    )

    Write-Output "Granting SystemAssigned Identity secret access to KeyVault $KeyVaultName... "
    Write-Output ''

    Set-AzKeyVaultAccessPolicy -VaultName $KeyVaultName `
        -ObjectId $ObjectId `
        -PermissionsToSecrets all `
        -PassThru

    Write-Output "Done.`n"   
}

Function Edit-KeyVaultNetworkRules {
    
    Param(
        [string] $KeyVaultName
    )

    Write-Output "`nUpdating KeyVault: $KeyVaultName network rules..."

    # Configure Network Settings: Disable public access, enable Trusted Microsoft Services.s
    Update-AzKeyVaultNetworkRuleSet -VaultName $KeyVaultName -DefaultAction Deny -Bypass AzureServices

    Write-Output "Done updating KeyVault: $KeyVaultName network rules.`n"
}

Function Edit-VnetNetworkRules {
    
    Param(
        [string] $StorageAccountName,
        [string] $VnetName,
        [string] $SubnetName
    )

    # Get VNET and Subnet objects
    $vnet = Get-AzVirtualNetwork -ResourceGroupName $LabRg -Name $vnetName
    $subnet = $vnet | Get-AzVirtualNetworkSubnetConfig -Name $SubnetName
    
    # We want to add a new ServiceEndpoint without overriding existing ones.
    $serviceEndPoints = New-Object 'System.Collections.Generic.List[String]'
    $subnet.ServiceEndpoints | ForEach-Object { $serviceEndPoints.Add($_.service) }
    
    # Duplicating a service endpoint in the list will cause a 400 Bad Request failure.
    if ($serviceEndPoints -notcontains 'Microsoft.Storage') {
        $serviceEndPoints.Add("Microsoft.Storage")

        # Add a ServiceEndpoint to the VNET subnet
        $vnet `
        | Set-AzVirtualNetworkSubnetConfig -Name $SubnetName -AddressPrefix $subnet.AddressPrefix -ServiceEndpoint $serviceEndPoints `
        | Set-AzVirtualNetwork `
        | Out-Null

        # Add Lab VNET to the Storage Account
        Add-AzStorageAccountNetworkRule -ResourceGroupName $LabRg -Name $StorageAccountName -VirtualNetworkResourceId $subnet.Id
    }
    else {
        Write-Output "`Service Endpoint for Microsoft.Storage already exists in this Subnet configuration, skipping."
    }
}

Function Edit-ExistingLabToUseIsolatedNetwork {
    
    Param(
        $LabObject
    )
    ################################################################################
    # Step 1. Ensure there is a SystemAssigned Identity
    ################################################################################
    
    $addSystemAssigned = $false
    $ManagedIdentityType = $LabObject.Identity.Type

    if ($ManagedIdentityType -inotcontains 'SystemAssigned') {
        Write-Output "No system assigned identity found."
        $addSystemAssigned = $true

        if ($ManagedIdentityType -ieq 'None') {
            $LabObject.identity.type = 'SystemAssigned'
        }

        if ($ManagedIdentityType -ieq 'UserAssigned') {
            $LabObject.identity.type = 'SystemAssigned,UserAssigned'
        }
    }

    if ($addSystemAssigned -eq $true) {
        Write-Output "Adding SystemAssigned identity to lab."
        $payload = $LabObject | ConvertTo-Json
        Set-LabObject -Payload $payload
    }

    $labObject = Get-LabObject

    # Lab properties return the entire resourceId of the member fields we're accessing.
    # We just want the name of the vault so remove the rest. 
    $dtlVaultName = Get-NameFromResourceId $LabObject.Properties.vaultName
    $storageAccountName = Get-NameFromResourceId $LabObject.Properties.artifactsStorageAccount

    Write-Output ''
    Write-Output "Found DTL created resources: "
    Write-Output "KeyVault: $dtlVaultName"
    Write-Output "Storage Account: $storageAccountName"
    Write-Output ''

    ################################################################################
    # Step 2. Adjust permissions and network settings for all of the KeyVaults
    ################################################################################

    # Add necessary KeyVault permissions to SystemAssigned Identity
    if ($addSystemAssigned -eq $true) {
        Edit-SystemAssignedIdentityKeyVaultPermissions -KeyVaultName $dtlVaultName `
            -ObjectId $labObject.Identity.principalId
    }

    Write-Output "`nModifying the DTL created KeyVault..."
    Edit-KeyVaultNetworkRules -KeyVaultName $dtlVaultName

    # Also make sure we modify all the KeyVaults of all the Lab users. 
    $allLabUsersList = Get-AllLabUsers

    Write-Output "`nCheck if any Lab users have additional KeyVaults..."
    Write-Output ''

    foreach ($user in $allLabUsersList.value) {
        $userName = $user.name
        
        Write-Host "Found Lab User: $userName"

        $userVaultUri = $user.secretStore.keyVaultUri
        
        # Might be empty
        if ($null -ne $userVaultUri) {
            Write-Host "With KeyVault: $userVaultUri"
            
            $userVaultName = Get-NameFromResourceId $userVaultUri
            
            # Add necessary KeyVault permissions to SystemAssigned Identity
            if ($addSystemAssigned -eq $true) {
                Edit-SystemAssignedIdentityKeyVaultPermissions -KeyVaultName $userVaultName `
                    -ObjectId $labObject.Identity.principalId
            }

            Edit-KeyVaultNetworkRules -KeyVaultName $userVaultName
        }
        else { 
            Write-Host "Lab User: $userName did not have an associated secret store."
        }
    }
    
    Write-Output "`nDone updating KeyVault related permissions."
    Write-Output ""

    ################################################################################
    # Step 3. Adjust permissions and network settings for all the Storage Accounts
    ################################################################################
    
    if ($addSystemAssigned -eq $true) {
        Write-Output "Granting SystemAssign identity RBAC permission - Blob Storage Contributor."

        # Get latest data again, need to do this.
        $labObject = Get-LabObject

        New-AzRoleAssignment -ObjectId $labObject.identity.principalId `
            -RoleDefinitionName "Storage Blob Data Contributor" `
            -Scope  "/subscriptions/$SubscriptionId/resourceGroups/$LabRg/providers/Microsoft.Storage/storageAccounts/$StorageAccountName"

        Write-Output "Done updating RBAC permissions.`n"
    }

    Write-Output "`nUpdating Storage Account: $StorageAccountName network rules..."

    # Configure Network Settings: Disable public access, enable Trusted Microsoft Services.
    Update-AzStorageAccountNetworkRuleSet -ResourceGroupName $LabRg -Name $StorageAccountName -DefaultAction Deny -Bypass AzureServices

    # Configure VNET(s) settings and network configuration.
    $allLabVnetsList = Get-AllLabVnets

    Write-Output "`nUpdating VNET network configurations..."
    Write-Output ''

    foreach ($vnet in $allLabVnetsList.value) {
        $vnetName = $vnet.name
        Write-Output "Found VNET: $vnetName"

        foreach ($subnet in $vnet.properties.subnetOverrides) {
            $subnetName = $subnet.labSubnetName
            Write-Output '----------------------------------------'
            Write-Output "`tOperating on Subnet: $subnetName`n"

            if ($subnet.useInVmCreationPermission -eq "Allow") {
                Write-Output "Found useInVmCreationPermission=Allow, so updating rules..."

                Edit-VnetNetworkRules -StorageAccountName $storageAccountName `
                    -VnetName $vnetName `
                    -SubnetName $subnetName
            }
            else {
                Write-Output "Did not find useInVmCreationPermission=Allow, skipping this subnet."
            }
        }
    }

    Write-Output "`nDone updating Storage Account and VNET(s) related permissions."

    ################################################################################
    # Step 4. Update Lab: Set resourceNetworkIsolation = Enabled 
    ################################################################################
    Write-Output "Updating $LabName IsolateLabResources property to 'Enabled'..."

    # Refresh lab object in case we made other changes.
    $labObject = Get-LabObject

    # This is the property that we now want to update on the lab.
    # Make sure that this step is always done last.
    $labObject.properties.isolateLabResources = 'Enabled'
    $payload = $labObject | ConvertTo-Json
    Set-LabObject -Payload $payload

    $labObject = Get-LabObject
    $finalProps = $labObject.properties | ConvertTo-Json

    Write-Output "`nFinal lab properties."
    Write-Output $finalProps
}


################################################################################
# Starting Point
################################################################################

Write-Output ''
Write-Output '###########################################################################'
Write-Output '##                        Operating Parameters'
Write-Output "## SubscriptionId:                $SubscriptionId"
Write-Output "## Lab Resource Group:            $LabRg"
Write-Output "## Lab:                           $LabName"
Write-Output '###########################################################################'
Write-Output ''

$context = Get-AzContext

if ($null -eq $context) {
    Write-Output "Log in to authenticate..."
    Connect-AzAccount -Subscription $SubscriptionId
}

if ($context.Subscription.Id -ne $SubscriptionId) {
    Set-AzContext -Subscription $subscriptionId
}

$labObject = Get-LabObject

if ($labObject.properties.isolateLabResources -eq 'Enabled') {
    Write-Output "Lab already in an isolated network. Skipping."
}
else {
    Edit-ExistingLabToUseIsolatedNetwork -LabObject $labObject
}

Write-Output "`n###########################"
Write-Output "Script is Done!"
Write-Output "`n###########################"

