# Add Marketplace Image to lab

This script provides a way to add a new allowed Marketplace Image to a DevTest Lab via Azure PowerShell. Before running the script you need to log in to your azure account and select the subscription which contains the lab.

The script takes two parameters - the first specifies the name of the DevTestLab. The second is an array containing the display names of the marketplace image(s) to be added. The list of images specified will be added to the list of allowed images in the lab, so any previously allowed marketplace images will continue to be allowed. If the lab currently allows all marketplace images then no action will be taken.

Examples:

```powershell
Login-AzureRmAccount
Select-AzureRmSubscription -SubscriptionId ...

# Add one additional image to the lab
.\AddMarketplaceImages.ps1 -DevTestLabName 'MyDevTestLab' -ImagesToAdd 'Windows Server 2016 Datacenter'

# Add multiple additional images to the lab
.\AddMarketplaceImages.ps1 -DevTestLabName 'MyDevTestLab' -ImagesToAdd 'Windows Server 2016 Datacenter', 'Red Hat Enterprise Linux 7.3'
```