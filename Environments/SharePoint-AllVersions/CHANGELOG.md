# Change log for AzureRM template SharePoint-AllVersions-LightConfig

## Enhancements & bug-fixes - Published in September 17, 2020

* Re-add creation of SPDistributedCacheService
* Re-add xCredSSP configuration
* Disable IE Enhanced Security Configuration (ESC) on SharePoint VMs
* Disable the first run wizard of IE on SharePoint VMs
* Set new tabs to open "about:blank" in IE on SharePoint VMs

## September 2020 update

* Many modifications on DSC scripts to improve their reliability, readability and consistency
* Create default SharePoint security groups on team site
* Ensure compliance with policy CASG-DenyNSGRule100Allow

## August 2020-08-18 update

* Revert SP and SQL to old VM sizes due to issues with Edsv4-series in "East US" since today (they fail to start)

## August 2020 update 3

* Update DSC configuration of all VMs to make deployment much more reliable after the change to fix the time out issue

## August 2020 update 2

* Fix timeout issue / DSC not resuming after VM reboot: Update dependencies of DSC extensions of SP and SQL, so they no longer depend on DSC of DC
* Replace DSC module xActiveDirectory with ActiveDirectoryDsc 6.0.1

## August 2020 update

* Update VM sizes to more recent, powerful and cheaper ones (prices per month in West US as of 2020-08-11):
  - DC: from [Standard_F4](https://docs.microsoft.com/en-us/azure/virtual-machines/sizes-previous-gen?toc=/azure/virtual-machines/linux/toc.json&bc=/azure/virtual-machines/linux/breadcrumb/toc.json) ($316.09) to [Standard_DS2_v2](https://docs.microsoft.com/en-us/azure/virtual-machines/dv2-dsv2-series) ($183.96)
  - SQL: from [Standard_D2_v2](https://docs.microsoft.com/en-us/azure/virtual-machines/dv2-dsv2-series) ($183.96) to [Standard_E2ds_v4](https://docs.microsoft.com/en-us/azure/virtual-machines/edv4-edsv4-series) ($185.42)
  - SP: from [Standard_D11_v2](https://docs.microsoft.com/en-us/azure/virtual-machines/dv2-dsv2-series-memory) ($192.72) to [Standard_E2ds_v4](https://docs.microsoft.com/en-us/azure/virtual-machines/edv4-edsv4-series) ($185.42)

## July 2020 update

* Update SQL to SQL Server 2019 on Windows Server 2019
* Add a network security group to Azure Bastion subnet
* Rename some resources and variables with more meaningful names
* Update apiVersion of each resource to latest version
* Update DSC module NetworkingDsc from 7.4 to 8.0
* Update DSC module xPSDesiredStateConfiguration from 8.10 to 9.1
* Update DSC module ActiveDirectoryCSDsc from 4.1 to 5.0
* Update DSC module xDnsServer from 1.15 to 1.16
* Update DSC module ComputerManagementDsc from 7.0 to 8.3
* Update DSC module SqlServerDsc from 13.2 to 14.1
* Update DSC module xWebAdministration from 2.8 to 3.1.1
* Update DSC module SharePointDSC from 3.6 to 4.2

## June 2020 update

* Fix deployment error in region "eastus2euap" caused by a subnet prefix policy

## February 2020 update

* Fix deployment error caused by the new values of the SKU of SharePoint images, which changed from '2013' / '2016' / '2019' to 'sp2013' / 'sp2016' / 'sp2019'
* Update the schema of deploymentTemplate.json to latest version

## November 2019 update

* Remove configuration of AD CS if parameter ConfigureADFS is set to No, to speed up the deployment time of the template
* Open SQL port on the firewall only when SQL VM is fully configured, as SharePoint DSC is testing it to start creation of the farm

## October 2019 update

* Add parameter ConfigureADFS, set to No by default, to skip the whole ADFS configuration if it is not desired. This speeds up the deployment time of the template
* Add optional service Azure Bastion
* Rename parameter createPublicIPAndDNS to addPublicIPAddressToEachVM
* Parameter addPublicIPAddressToEachVM does not add any rule in network security groups if it is set to No, so that no inbound traffic is allowed from Internet. If set to Yes, only RDP port is allowed
* Replace SQL Server 2016 with SQL Server 2017
* Use SQL Server Developer edition instead of Standard edition. More info: <https://docs.microsoft.com/en-us/azure/virtual-machines/windows/sql/virtual-machines-windows-sql-server-pricing-guidance>
* Update DC to run with Windows Server 2019
* Update DSC module SharePointDSC from 3.5 (custom) to 3.6
* Update DSC module xPSDesiredStateConfiguration from 8.8 (custom) to 8.10
* Update DSC module NetworkingDsc from 7.3 to 7.4
* Update DSC module ActiveDirectoryCSDsc from 3.3 to 4.1
* Update DSC module xDnsServer from 1.13 to 1.15
* Update DSC module ComputerManagementDsc from 6.4 to 7.0
* Remove DSC module xPendingReboot, which is replaced by PendingReboot in ComputerManagementDsc 7.0
* Update DSC module SqlServerDsc from 13.0 to 13.2
* Update DSC module StorageDsc from 4.7 to 4.8
* Update DSC module xWebAdministration from 2.6 to 2.8

## July 2019 update

* Add the certificate of the domain root authority to the SPTrustedRootAuthority
* Use DSC resource xWebsite instead of xScript to configure HTTPS binding
* Update DSC module SharePointDSC to 3.5 with customization to add new resource SPTrustedSecurityTokenIssuer and fix SPTrustedRootAuthority
* Update DSC module xPSDesiredStateConfiguration to 8.8, with a customization on resource xRemoteFile to deal with random connection errors while downloading LDAPCP
* Update xActiveDirectory from 2.23 to 3.0
* Update NetworkingDsc from 6.3 to 7.3
* Update ActiveDirectoryCSDsc from 3.1 to 3.3
* Update CertificateDsc from 4.3 to 4.7
* Update xDnsServer from 1.11 to 1.13
* Update ComputerManagementDsc from 6.1 to 6.4
* Update SqlServerDsc from 12.2 to 13.0
* Update StorageDsc from 4.4 to 4.7

## May 2019 update

* Update DSC module SharePointDSC to 3.3
* Add logic to create an optional public IP address for VMs
* Force a reboot before creating site in SharePoint 2019 to workaround bug https://github.com/PowerShell/SharePointDsc/issues/990
* Remove parameter location and use function resourceGroup().location instead, to set location of resources
* Update apiVersion of all resources to latest version
* Update some properties description

## March 2019 update

* Initial release
