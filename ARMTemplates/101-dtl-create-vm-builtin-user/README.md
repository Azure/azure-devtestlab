# Create a new virtual machine in a DevTestLab instance.

<a href="https://portal.azure.com/#create/Microsoft.Template/uri/https%3A%2F%2Fraw.githubusercontent.com%2Fazure%2Fazure-devtestlab%2Fmaster%2FRMTemplates%2F101-dtl-create-vm-builtin-user%2Fazuredeploy.json" target="_blank">
    <img src="http://azuredeploy.net/deploybutton.png"/>
</a>


This deployment template is generally used with non-sysprepped VHDs containing a built-in user account.

This template creates a new virtual machine in a DevTestLab instance.
- No new user account is created during the VM creation.
- We assume that the original custom image already contains a built-in user account.
- We assume that this built-in account can be used to log into the VM after creation.
