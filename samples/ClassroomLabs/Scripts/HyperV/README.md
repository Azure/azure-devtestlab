# Introduction
This script will help prepare your template virtual machine for a classroom lab to use Hyper-V nested virtualization.

## Notes
- This script is written for Windows Server OSes, not for Windows Client OSes.
- Script must be executed using administrator privileges.

# Directions
1. Connect to template machine for your class.
2. Clone repository or download files in this folder onto the template machine.
3. Open a PowerShell window.  Make sure that the window notes it is running under administrator privileges.
4. Run `SetupForNestedVirtualization.ps1`.  
5. The script may ask you to restart the machine and re-run it.  A note that the script is completed will show if no further action is needed.
