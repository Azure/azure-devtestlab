**Note**: 
There are 2 types of updates when deploying your ARM templates: incremental update or a complete update. Please use **incremental update** when deploying ARM templates to create lab VMs. The complete update will lead to deletion of the lab. 

By default, Resource Manager handles deployments as incremental updates to the resource group. You can specify the type of deployment through the "Mode" property by passing "Incremental" or "Complete". 

To learn more about the difference in these two types of updates, please see Deploy resources with [Resource Manager templates and Azure PowerShell - increment and complete deployments](https://docs.microsoft.com/en-us/azure/azure-resource-manager/resource-group-template-deploy#incremental-and-complete-deployments).
