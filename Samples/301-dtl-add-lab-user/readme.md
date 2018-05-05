# Add Lab User to a DevTestLab instance

<a href="https://portal.azure.com/#create/Microsoft.Template/uri/https%3A%2F%2Fraw.githubusercontent.com%2FAzure%2Fazure-devtestlab%2Fmaster%2FSamples%2F301-dtl-add-lab-user%2Fazuredeploy.json" target="_blank">
    <img src="http://azuredeploy.net/deploybutton.png"/>
</a>


This template creates a new role assignment which adds the specified user or group as a DevTest Lab User to the specified DevTest Lab instance.

Parameters for template:

-  **principalId**.   Principal Id is the ObjectId of the AD user or group that you want to add as a user to the DevTest Lab instance.  This information can be obtained using the [Get-AzureRMADUser] (https://msdn.microsoft.com/en-us/library/mt619420.aspx), [Get-AzureRMAdGroup](https://msdn.microsoft.com/en-us/library/mt603729.aspx) or [Get-AzureRMADServicePrincipal](https://msdn.microsoft.com/en-us/library/mt603710.aspx) PowerShell cmdlets.
- **labName**. Name of lab to which you want to add the user.  Must be in same resource group that the arm template is being deployed to.
- **roleAssignmentGuid**.  Name of the role assignment.  This can be any valid GUID as explained by the [Role Assignments](https://docs.microsoft.com/en-us/rest/api/authorization/roleassignments) documentation.

