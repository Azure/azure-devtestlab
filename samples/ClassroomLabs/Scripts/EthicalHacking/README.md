# Introduction
This script will help prepare your template virtual machine for a ethical hacking class.  One virtual machine with a [Kali Linux](https://www.kali.org/) image is created.  Kali is a Linux distribution that includes tools for penetration testing and security auditing.  Another [Metasploitable](https://github.com/rapid7/metasploitable3) image is created.  The Rapid7 Metasploitable image is an image purposely configured with security vulnerabilities. You'll use this image to test and find issues. 

## Notes
- This script is written for Windows Server OSes, not for Windows Client OSes.
- Script must be executed using administrator privileges.

# Directions
1. Connect to template machine for your class.
2. Clone repository or download files in this folder onto the template machine.
3. Open a PowerShell window.  Make sure that the window notes it is running under administrator privileges.
4. Navigate to azure-devtestlab/samples/ClassroomLabs/Scripts.
5. Run `HyperV/SetupForNestedVirtualization.ps1`, if not done already.  This install the necessary features to create HyperV virtual machines. 

     Note: The script may ask you to restart the machine and re-run it.  A note that the script is completed will show in the PowerShell window if no further action is needed.
6. Run `EthicalHacking/Setup-EthicalHacking.ps1`
