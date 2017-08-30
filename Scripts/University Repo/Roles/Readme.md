# Create role with JSON template

A JSON template can be used as the source definition for the custom role. The following example creates a custom role that allows to connect, start, restart, and shutdown your virtual machines in your Azure DevTest Labs. You cannot create new VMs. Create a new file "University_DevTest Labs User.json" with the following content. The Id should be set to null on initial role creation as a new ID is generated automatically.

## Creating the json template
```
    {
        "Name": "University DevTest Labs User",
        "Id": null,
        "IsCustom": true,
        "Description": "Lets you connect, start, restart, and shutdown your virtual machines in your Azure DevTest Labs. You cannot create new VMs.",
        "Actions": [
            "Microsoft.Authorization/*/read",
            "Microsoft.Compute/availabilitySets/read",
            "Microsoft.Compute/virtualMachines/*/read",
            "Microsoft.Compute/virtualMachines/deallocate/action",
            "Microsoft.Compute/virtualMachines/read",
            "Microsoft.Compute/virtualMachines/restart/action",
            "Microsoft.Compute/virtualMachines/start/action",
            "Microsoft.DevTestLab/*/read",
            "Microsoft.DevTestLab/labs/claimAnyVm/action",
            "Microsoft.DevTestLab/labs/formulas/delete",
            "Microsoft.DevTestLab/labs/formulas/read",
            "Microsoft.DevTestLab/labs/formulas/write",
            "Microsoft.DevTestLab/labs/policySets/evaluatePolicies/action",
            "Microsoft.DevTestLab/labs/virtualMachines/claim/action",
            "Microsoft.Network/loadBalancers/backendAddressPools/join/action",
            "Microsoft.Network/loadBalancers/inboundNatRules/join/action",
            "Microsoft.Network/networkInterfaces/*/read",
            "Microsoft.Network/networkInterfaces/join/action",
            "Microsoft.Network/networkInterfaces/read",
            "Microsoft.Network/networkInterfaces/write",
            "Microsoft.Network/publicIPAddresses/*/read",
            "Microsoft.Network/publicIPAddresses/join/action",
            "Microsoft.Network/publicIPAddresses/read",
            "Microsoft.Network/virtualNetworks/subnets/join/action",
            "Microsoft.Resources/deployments/operations/read",
            "Microsoft.Resources/deployments/read",
            "Microsoft.Resources/subscriptions/resourceGroups/read",
            "Microsoft.Storage/storageAccounts/listKeys/action"
        ],
        "NotActions": [
            "Microsoft.Compute/virtualMachines/vmSizes/read"
        ],
        "AssignableScopes": [
            "/subscriptions/__SubscriptionID__"
        ]
    }
```

## Add the role to the subscriptions
To add the role to the subscriptions, run the following PowerShell command:

```
    New-AzureRmRoleDefinition -InputFile ".\University_DevTest Labs User.json"
```
