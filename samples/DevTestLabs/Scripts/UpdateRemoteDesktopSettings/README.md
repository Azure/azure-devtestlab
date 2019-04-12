# Updating the RDP settings in a DevTest Lab
Azure DevTest Labs has remote desktop configuration settings accessible by the Rest API!  This is done through `ExtendedProperties` in the lab.  The effect of setting these properties is that whenever a user clicks the "Connect" button on a Virtual Machine, the resulting generated RDP file will include the appropriate settings.  The available settings are:
* **Experience**:  Set the connection speed as a proxy for how much data to send over the network.  The RDP client sends & receives less information when a slower 'speed' is selected.  This is the same setting found in the RDP client (start -> Run, "mstsc", select "Experience" tab)
* **Remote Desktop Gatway**:  The RDP Gateway settings can be found on the "advanced" tab of the remote desktop client.  To enable the Lab to automatically use the RDP Gatway, just include the correct URL in the `ExtendedProperties`.

The syntax of the script is as follows:
```powershell

# Set only the Remote Desktop Gateway property for a lab, identified by the Resource Group Name and the DevTest Lab Name
.\Set-DTL-RemoteDesktopSettings.ps1 -ResourceGroupName "TeamA_rg" `
                                    -DevTestLabName "TeamA" `
                                    -RemoteDesktopGateway "customrds.eastus.cloudapp.azure.com"

# Set only the Experience Level property for a lab, identified by the ResourceId of the DevTest Lab
.\Set-DTL-RemoteDesktopSettings.ps1 -DevTestLabResourceId "/subscriptions/<subid>/resourceGroups/TeamA_rg/providers/Microsoft.DevTestLab/labs/TeamA" `
                                    -ExperienceLevel 2

# Clear the Remote Desktop Gateway and Experience level properrties in a lab
.\Set-DTL-RemoteDesktopSettings.ps1 -ResourceGroupName "TeamA_rg" -DevTestLabName "TeamA_DevResources"

```
Here's an example of what the Lab's properties object looks like (in JSON format) including the new Remote Desktop settings
```json
{
    "properties": {
        "defaultStorageAccount": "<Resource Id>",
        "defaultPremiumStorageAccount": "<Resource Id>",
        "artifactsStorageAccount": "<Resource Id>",
        "premiumDataDiskStorageAccount": "<Resource Id>",
        "vaultName": "<Resource Id>",
        "labStorageType": "Standard",
        "createdDate": "2018-06-03T23:26:00.5259483+00:00",
        "premiumDataDisks": "Disabled",
        "environmentPermission": "Reader",
        "announcement": {
            "markdown": "",
            "title": "",
            "enabled": "Disabled",
            "expirationDate": ""
        },
        "support": {
            "enabled": "Disabled",
            "markdown": ""
        },
        "extendedProperties": {
            "RdpConnectionType": "2",
            "RdpGateway": "customrds.eastus.cloudapp.azure.com"
        },
        "provisioningState": "Succeeded",
        "uniqueIdentifier": "7866e06e-7c34-45b2-ab97-7f2f87ef4cd7"
    },
    "id": "<Resource Id>",
    "name": "<Lab Name>",
    "type": "Microsoft.DevTestLab/labs",
    "location": "eastus",
    "tags": {}
}
```
