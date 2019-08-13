# RDGateway enabled Environments

## Windows Jumpbox To Two Linux VMs
TThis environment has three VMs, one Windows 10 and 2 Linux. The Windows 10 VM can only be accessed using a token from the RDG gateway. It is the only VM that can access the two inner Linux VMs. The two Linux VMs can access the Windows 10 VM and each other. The ARM template includes the following:
- Virtual machines with NICs connected to the DevTest Lab subnet.
- Application Security Group(s) to group the Linux VMs, and wrap the Windows VM.
- Network Security Group with appropriate security rules that use the Application Security groups to control access.

## Requirements for Windows Jumpbox To Two Linux VMs

The following parameters are required to create a WindowsJumpboxToTwoLinuxVMs environment:
* JMPvmName - Jumpbox VM name.
* JMPadminName - Jumpbox VM administrator name.
* JMPadminPassword - Jumpbox VM administrator password.
* LINAvmName - Linux A VM name.
* LINAadminName - Linux A VM administrator name.
* LINAadminPassword - Linux A VM administrator SSH key.
* LINBvmName - Linux B VM name.
* LINBadminName - Linux B VM administrator name.
* LINBadminPassword - Linux B VM administrator SSH key.
## Details
All VMs have Private IPs and are connected to the DevTest Lab subnet. There are two Application Security Groups (ASG) for the Windows VM and the two Linux VMs. These ASGs are used in the security rules of the Network Security Group (NSG) to avoid dependency conflict issues with the two Linux VMs.

The Windows VM will need to have Network Discovery turned on to allow the Linux VMs to see it.

## Important Note

By using template, you agree to Remote Desktop Gateways terms. Click here to read [RD Gateway license terms](https://www.microsoft.com/en-us/licensing/product-licensing/products).  

For further information regarding Remote Gateway see [https://aka.ms/rds](https://aka.ms/rds) and [Deploy your Remote Desktop environment](https://docs.microsoft.com/en-us/windows-server/remote/remote-desktop-services/rds-deploy-infrastructure).