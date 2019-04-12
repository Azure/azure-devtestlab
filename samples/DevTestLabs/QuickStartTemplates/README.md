You can find various quick-start Azure Resource Manager templates here that show case how to provision DevTest Labs resources (labs, custom images, formulas, lab VMs, etc.): 

* The 101-301 samples focus on a single topic in each. 
* The sample ProvisionDemoLab provides a complete ARM template that creates a lab with policy settings, custom images, a custom artifact repo and a couple of VMs for demo purpose.

**Note**: 
By default, Resource Manager handles deployments as incremental updates to the resource group. One can specify the type of deployment through the **Mode** property by passing "Incremental" or “Complete”.  **DO NOT** use Complete mode when deploying ARM templates to create lab VMs, as the Complete Mode will lead to deletion of the lab.

To learn more about the difference in these two types of updates, please see Deploy resources with [Resource Manager templates and Azure PowerShell - increment and complete deployments](https://docs.microsoft.com/en-us/azure/azure-resource-manager/resource-group-template-deploy#incremental-and-complete-deployments).
