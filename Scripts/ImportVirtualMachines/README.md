# Importing Virtual Machines into a DevTest Lab
Azure DevTest Labs is now able to copy or move a Virtual Machine from one lab to another!  This is done through the new "ImportVirtualMachine" action provided in the DevTest Labs Rest API.

The Rest API enables copying a single virtual machine from one lab to another and optionally renaming the virtual machine.  The ImportVirtualMachines.ps1 powershell script automates this process allowing you to import a single virtual machine or ALL the virtual machines in a lab.

There are two important caveats in using this script:
* The source DevTest Lab and destination DevTest Lab must be in a subscription associated to the same Azure Active Directory tenant
* The virtual machine in the source lab must NOT be in a 'claimable' state

To learn more about this feature and scenarios where it's used, see blog post [Importing Virtual Machines](https://blogs.msdn.microsoft.com/devtestlab/2018/05/18/importing-virtual-machines-across-labs/).

If you're using **Powershell 5** please use "ImportVirtualMachines.ps1", for **Powershell 6** please use "ImportVirtualMachines_ps6.ps1".

The syntax of the script is as follows:
```powershell

# Import ALL the virtual machines from the Source lab into the Destination lab
.\ImportVirtualMachines.ps1 -SourceSubscriptionId "a9af5216-f1fb-420e-a146-3fdd011b696e" `
                            -SourceDevTestLabName "TeamA_DevResources" `
                            -DestinationSubscriptionId "cf7d95cd-57fc-4713-b0c1-db9d9b633b67" `
                            -DestinationDevTestLabName "TeamB"

# Import a single virtual machine Source lab into the Destination lab and rename it during import
.\ImportVirtualMachines.ps1 -SourceSubscriptionId "a9af5216-f1fb-420e-a146-3fdd011b696e" `
                            -SourceDevTestLabName "TeamA_DevResources" `
                            -SourceVirtualMachineName "MyCustomDevBox" `
                            -DestinationSubscriptionId "cf7d95cd-57fc-4713-b0c1-db9d9b633b67" `
                            -DestinationDevTestLabName "TeamB" `
                            -DestinationVirtualMachineName "PersonalDevBox"

```
