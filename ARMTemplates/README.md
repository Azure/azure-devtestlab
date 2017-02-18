**Note**: 
By default, Resource Manager handles deployments as incremental updates to the resource group. One can specify the type of deployment through the **Mode** property by passing "Incremental" or “Complete”.  **DO NOT** use Complete mode when deploying ARM templates to create lab VMs, as the Complete Mode will lead to deletion of the lab.

To learn more about the difference in these two types of updates, please see Deploy resources with [Resource Manager templates and Azure PowerShell - increment and complete deployments](https://docs.microsoft.com/en-us/azure/azure-resource-manager/resource-group-template-deploy#incremental-and-complete-deployments).
