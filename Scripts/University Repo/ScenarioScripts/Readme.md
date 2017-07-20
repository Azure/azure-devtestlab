This folder contains:
Powershell scripts file which needs to be run either via Console or via Automation account on Azure to set up the environments for 
the imagined scenarios.

Add-AzureDtlVM: This script adds the specified number of Azure virtual machines to a DevTest Lab.

Add-AzureDtlVMAutoVar: This script adds the number of Azure virtual machines in the DevTest Lab by reading some parameters 
from AutomationVariable.

Add-GroupPermissionsDevTestLab: This script adds the specified role to the AD Group in the DevTest Lab.

Common: This script contains many useful functions for the other scripts.

DeallocateStoppedVM: This script deallocates every stopped Azure virtual machines.

Manage-AzureDtlFixedPool: This script guarantees that the Virtual Machine pool of the Lab equals to the PoolSize specified as Azure Tag 
of Lab.

Remove-AzureDtlLabVMs: This script guarantees that the Virtual Machine pool of the Lab equals to the PoolSize specified as Azure Tag of Lab.

Remove-AzureDtlVM: This script deletes every Azure virtual machines in the DevTest Lab.

Remove-GroupPermissionsDevTestLab: This script removes the specified role from the AD Group in the DevTest Lab.

Test-AzureDtlVMs: Given LabName and LabSize, this script verifies how many Azure virtual machines are inside the DevTest Lab 
and throws an error inside the logs when the number is greater or lower than size +/- VMDelta.
