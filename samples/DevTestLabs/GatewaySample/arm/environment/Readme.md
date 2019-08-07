# RDGateway enabled Environments

## WindowsJumpboxToTwoLinuxVMs
This environment has three VMs, Windows 10 and 2 Linux, where the Windows VM can only be remoted to using a token from the RDG gateway and is the only VM that can access the two inner Linux VMs.  The two Linux VMs can access the Windows box and each other.  The ARM template includes the following:
- Virtual machines with NICs connected to the DevTest Lab subnet.
- Application Security Group(s) to group the Linux VMs, and wrap the Windows VM.
- Network Security Group with appropriate security rules that use the Application Security groups to control access.

### Requirements for WindowsJumpboxToTwoLinuxVMs

The following to parameters are required to create a WindowsJumpboxToTwoLinuxVMs environment:
* JMPvmName - Jumpbox VM name.
* JMPadminName - Jumpbox VM administrator name.
* JMPadminPassword - Jumpbox VM administrator password.
* LINAvmName - Linux A VM name.
* LINAadminName - Linux A VM administrator name.
* LINAadminPassword - Linux A VM administrator SSH key.
* LINBvmName - Linux B VM name.
* LINBadminName - Linux B VM administrator name.
* LINBadminPassword - Linux B VM administrator SSH key.

## Important Note

NOTE: By using template, you agree to Remote Desktop Gateway�s terms. Click here to read [RD Gateway license terms](https://www.microsoft.com/en-us/licensing/product-licensing/products).  

For further information regarding Remote Gateway see [https://aka.ms/rds](https://aka.ms/rds) and [Deploy your Remote Desktop environment](https://docs.microsoft.com/en-us/windows-server/remote/remote-desktop-services/rds-deploy-infrastructure).