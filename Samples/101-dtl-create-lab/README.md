# Create a new DevTestLab instance

<a href="https://portal.azure.com/#create/Microsoft.Template/uri/https%3A%2F%2Fraw.githubusercontent.com%2FAzure%2Fazure-devtestlab%2Fmaster%2FSamples%2F101-dtl-create-lab%2Fazuredeploy.json" target="_blank">
    <img src="http://azuredeploy.net/deploybutton.png"/>
</a>


This template creates a new DevTestLab instance.

When deploying via PowerShell, if you use -DeploymentMode parameter, it is recommended to use the "Incremental" option. The "Complete" option will delete the target resource group first. If a lab or other resources are in that resource group, you could lose them or encounter errors.
