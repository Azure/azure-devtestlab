# Introduction
This script will help prepare your template virtual machine for a classroom lab to use Hyper-V nested virtualization.

## Notes
- Script must be executed using administrator privileges.
- If running this script on a client O.S. like Windows 10 which does not support DHCP Server, the IP settings will need to be set within the VMs.
    - see https://support.microsoft.com/en-us/help/15089/windows-change-tcp-ip-settings for more details on Windows 10/8/7 operating systems.

# Directions
1. Connect to template machine for your class.
2. Clone repository or download files in this folder onto the template machine.
3. Open a PowerShell window.  Make sure that the window notes it is running under administrator privileges.
4. Run `SetupForNestedVirtualization.ps1`.  
5. The script may ask you to restart the machine and re-run it.  A note that the script is completed will show if no further action is needed.
