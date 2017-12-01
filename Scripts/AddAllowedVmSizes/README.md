# Add allowed VM Size to lab

This script provides a way to add a new "allowed virtual machine size" to a DevTest Lab via Azure PowerShell. Before running the script you need to log in to your azure account and select the subscription which contains the lab.

The script takes two parameters - the first specifies the name of the DevTestLab. The second is an array containing the names of the size(s) to be added. This array of sizes will be added to the list of currently-allowed sizes in the lab. Any previously allowed sizes will continue to be allowed.

Examples:

```powershell
Login-AzureRmAccount
Select-AzureRmSubscription -SubscriptionId ...

# Add one additional size to the lab
.\AddAllowedVMSizes.ps1 -DevTestLabName 'MyDevTestLab' -SizesToAdd 'Standard_A4'

# Add multiple additional sizes to the lab
.\AddAllowedVMSizes.ps1 -DevTestLabName 'MyDevTestLab' -SizesToAdd 'Standard_A4', 'Standard_DS3_v2'
```