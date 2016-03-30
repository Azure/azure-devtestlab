# Create a new virtual machine in a DevTestLab instance.

<a href="https://portal.azure.com/#create/Microsoft.Template/uri/https%3A%2F%2Fraw.githubusercontent.com%2Fazure%2Fazure-devtestlab%2Fmaster%2FRMTemplates%2F101-dtl-create-vm-username-pwd%2Fazuredeploy.json" target="_blank">
    <img src="http://azuredeploy.net/deploybutton.png"/>
</a>


This deployment template is generally used with sysprepped VHDs.

This template creates a new virtual machine in a DevTestLab instance.
- A new user account is created using the username/password combination specified. 
- This user account is added to the local administrators group.
