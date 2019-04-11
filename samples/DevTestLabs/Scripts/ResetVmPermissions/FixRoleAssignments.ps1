# Example ./FixRoleAssignments.ps1 -SubscriptionIds ('sub1','sub2','sub3') -LabRoleToAdd "DevTest Labs User"
param
(
    [Parameter(Mandatory=$false, HelpMessage="If you want to optionally target specific subscriptions instead of all of them, pass them in as a set")]
    [Array] $SubscriptionIds,

    [Parameter(Mandatory=$false, HelpMessage="If we should ALSO give VM Owners rights to the DevTest Lab, specify the Lab role - either DevTest Lab User, or Owner")]
    [ValidateSet("DevTest Labs User", "Owner", "")]
    [string] $LabRoleToAdd = ""
)

if ($SubscriptionIds -eq $null) {
    $SubscriptionIds  = Get-AzureRmSubscription
}

foreach ($subscription in $SubscriptionIds) {

    # select the subscription
    $sub = Select-AzureRmSubscription -SubscriptionId $subscription

    if ($sub -eq $null) {
        Write-Output "Unable to find any subscriptions.  Perhaps you need to run 'Add-AzureRmAccount' and login before running this script? Unable to proceed."
        return
    }

    # Give me all labs in the subscription
    $devTestLabs = Find-AzureRmResource -ResourceType 'Microsoft.DevTestLab/labs'

    foreach ($devTestLab in $devTestLabs) {
        
        
        # Get all the VMs in the lab
        $virtualMachines = Get-AzureRmResource -ResourceId "$($devTestLab.ResourceId)/virtualmachines" -ApiVersion 2016-05-15 

        foreach ($virtualMachine in $virtualMachines) {
            # Get the owner of the VM

            $ownerId = $virtualMachine.Properties.ownerObjectId
            $ownerName= $virtualMachine.Properties.ownerUserPrincipalName

            # the owner can be blank for really old VMs, let's copy created by if machine isn't claimable
            if (($virtualMachine.Properties.allowClaim -eq $false) -and ($ownerId -eq $null)) {
                $ownerId = $virtualMachine.Properties.createdByUserId
                $ownerName = $virtualMachine.Properties.createdByUser
            }

            # if we have the owner Id, let's check the permissions
            if (($ownerId -ne $null) -and ($ownerId.Trim().Length -gt 0) ) {
                
                $parentResource = ("labs/" + $devTestLab.Name)

                # If the VM role assignment doesn't exist, let's add it back
                $existing = Get-AzureRmRoleAssignment -ObjectId $ownerId `
                                                      -RoleDefinitionName "Owner" `
                                                      -ResourceGroupName $virtualMachine.ResourceGroupName `
                                                      -ResourceName $virtualMachine.Name `
                                                      -ResourceType $virtualMachine.ResourceType `
                                                      -ParentResource $parentResource `
                                                      | Where-Object {$_.Scope -like "*/virtualMachines/*"}
                if ($existing -eq $null) {
                    Write-Output "Fixing missing Virtual Machine Role Assignment, SubId: $($virtualMachine.SubscriptionId), VM RG: $($virtualMachine.ResourceGroupName), VM Name: $($virtualMachine.Name), RoleName: Owner, OwnerId : $ownerId, Owner Email: $ownerName"

                    $temp = New-AzureRmRoleAssignment -ObjectId $ownerId `
                                                      -RoleDefinitionName "Owner" `
                                                      -ResourceGroupName $virtualMachine.ResourceGroupName `
                                                      -ResourceName $virtualMachine.Name `
                                                      -ResourceType $virtualMachine.ResourceType `
                                                      -ParentResource $parentResource
                }

                # if the Lab role assignment doesn't exist, and we're supposed to add it, let's do it
                if ($LabRoleToAdd -ne "") {
                        $existing = Get-AzureRmRoleAssignment -ObjectId $ownerId `
                                                              -RoleDefinitionName $LabRoleToAdd `
                                                              -ResourceGroupName $devTestLab.ResourceGroupName `
                                                              -ResourceName $devTestLab.Name `
                                                              -ResourceType 'Microsoft.DevTestLab/labs' `
                                                              | Where-Object {$_.Scope -notlike "*/virtualMachines/*"}

                        if ($existing -eq $null) {
                            Write-Output "Fixing missing Lab Role Assignment, SubId: $($devTestLab.SubscriptionId), LabName: $($devTestLab.Name), RoleName: $LabRoleToAdd, OwnerId : $ownerId, Owner Email: $ownerName"
                            $temp = New-AzureRmRoleAssignment -ObjectId $ownerId `
                                                              -RoleDefinitionName $LabRoleToAdd `
                                                              -ResourceGroupName $devTestLab.ResourceGroupName `
                                                              -ResourceName $devTestLab.Name `
                                                              -ResourceType 'Microsoft.DevTestLab/labs' 
                        }

                }
            }

        }
    }
}
