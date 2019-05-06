# Change log for AzureRM template SharePoint-ADFS-DevTestLabs

## May 2019 update

* Update DSC module SharePointDSC to 3.3
* Add logic to create an optional public IP address for VMs
* Force a reboot before creating site in SharePoint 2019 to workaround bug https://github.com/PowerShell/SharePointDsc/issues/990
* Remove parameter location and use function resourceGroup().location instead, to set location of resources
* Update apiVersion of all resources to latest version

## March 2019 update

* Initial release
