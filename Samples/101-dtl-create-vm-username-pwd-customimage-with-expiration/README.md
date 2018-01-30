# Creates a new virtual machine in a Lab with a specified expiration date.

<a href="https://portal.azure.com/#create/Microsoft.Template/uri/https%3A%2F%2Fraw.githubusercontent.com%2Fazure%2Fazure-devtestlab%2Fmaster%2FSamples%2F101-dtl-create-vm-username-pwd-customimage-with-expiration%2Fazuredeploy.json" target="_blank">
    <img src="http://azuredeploy.net/deploybutton.png"/>
</a>


This deployment template is generally used for creating a virtual machine using a custom image (pointing to a sysprepped VHD file) .

This template creates a new virtual machine in a Lab with a expiration date.
- A new user account is created using the username/password combination on the virtual machine.
- The user account is added to the local administrators group.
- A expiration date is set for the VM.
- VM will be deleted within 24 hrs of expiration date.
