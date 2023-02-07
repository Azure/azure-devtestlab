# Change log for Azure DevTest Labs template SharePoint-AllVersions

## Enhancements & bug-fixes - Published in February 07, 2023

### Added

- Template
  - Added value `Subscription-latest` to parameter `sharePointVersion`, to install the January 2023 CU on SharePoint Subscription
- Configuration for DC
  - Create additional users in AD, in a dedicated OU `AdditionalUsers`
- Configuration for SQL
  - Install SQL module `SqlServer` (version 21.1.18256) as it is the preferred option of `SqlServerDsc`
- Configuration for all SharePoint versions
  - Create various desktop shortcuts
  - Configure Windows explorer to always show file extensions and expand the ribbon

### Changed

- Template
  - Revert SQL image to SQL Server 2019, due to reliability issues with SQL Server 2022 (SQL PowerShell modules not ready yet)
- Configuration for DC
  - Review the logic to allow the VM to restart after the AD FS farm was configured (as required), and before the other VMs attempt to join the domain
- Configuration for all VMs except DC
  - Review the logic to join the AD domain only after it is guaranteed that the DC is ready. This fixes the most common cause of random deployment errors

## Enhancements & bug-fixes - Published in January 10, 2023

* Use a small disk (32 GB) on SharePoint Subscription and SharePoint 2019 VMs.
* Updated SQL image to use SQL Server 2022 on Windows Server 2022.
* Now the resource group's name is used in the virtual network and the public IP resources, but it is formatted to handle the restrictions on the characters allowed.
* Apply browser policies for Edge and Chrome to get rid of noisy wizards / homepages / new tab content.
* No longer explicitly install Edge browser on Windows Server 2022 VMs as it is present by default.
* Reorganize the local template variables to be more consistent.
* In SharePoint VMs: Install the latest version of Fiddler.
* Update apiVersion of ARM resources to latest version available.
* Update DSC modules to latest version available.

## Enhancements & bug-fixes - Published in November 28, 2022

* Always install and configure AD CS.
* Renamed parameter `addPublicIPAddressToEachVM` to `addPublicIPAddress` and changed its type to `string` to provide more granularity. Its default value is now `"SharePointVMsOnly"`, to assign a public IP address only to SharePoint VMs
* Move the definition of SharePoint Subscription packages list from DSC to the template itself.
* Improve the logic that installs SharePoint updates when deploying SharePoint Subscription.
* Warm up SharePoint sites at the end of the configuration.
* Revert the previous change on the SKU of Public IP addresses, to use again SKU basic when possible (except for Bastion which requires Standard).
* Revert the previous change on the allocation method of Public IP addresses to use Dynamic instead of Static (except for Bastion which requires Static).
* Fixed the random error `NetworkSecurityGroupNotCompliantForAzureBastionSubnet` when deploying Azure Bastion by updating the rules in the network security group attached to Bastion's subnet.
* Update apiVersion of ARM resources to latest version available.
* Update DSC modules used to latest version available.
* Replace DSC module xDnsServer 2.0.0 with DnsServerDsc 3.0.0.

## Enhancements & bug-fixes - Published in September 29, 2022

* Add an option to create a SharePoint Subscription farm running with feature update 22H2.
* Use a gen2 image for SQL Server VM.
* Enable LDAPS (LDAP over SSL) on the Active Directory domain.
* Change SKU of Public IP addresses to Standard, since Basic SKU will be retired
* Update apiVersion of ARM resources.
* Replace DSC module xWebAdministration 3.3.0 with WebAdministrationDsc 4.0.0.

## Enhancements & bug-fixes - Published in August 8, 2022

* In SP SE, import site certificate in SharePoint, so it can manage the certificate itself.
* Update LDAP security settings to mitigate CVE-2017-8563.
* Remove tags on resources, as they did not bring any particular value.
* Update apiVersion of resources to latest version.
* Explicitly set the version of each DSC module used.
* Update DSC modules used to latest version available.
* Replace all resources xScript with Script and remove dependency on module xPSDesiredStateConfiguration.
* Add publicIPAddressSPSE to template output.

## Enhancements & bug-fixes - Published in January 10, 2022

* Add SharePoint Server Subscription and make it the default choice.
* Change Windows image of VM DC to Windows Server 2022 Azure Edition.
* Change disk size of VM DC to 32 GB.
* Change image of VM SQL to SQL Server 2019 on Windows Server 2022.
* Change disk type of all virtual machines to StandardSSD_LRS.
* Update DSC module SharePointDSC from 4.8 to 5.0.
* Update DSC module ComputerManagementDsc from 8.4 to 8.5.

## Enhancements & bug-fixes - Published in October 4, 2021

* Improve reliability of DSC module cChoco, which caused most of the deployment errors.
* Add output variable domainAdminAccountFormatForBastion.

## Enhancements & bug-fixes - Published in September 13, 2021

* Fix the error when browsing the team site collection in SharePoint 2019 by updating SharePointDSC to 4.8.
* Change default size of virtual machines to use B-series burstable, ideal for such template and much cheaper than other comparable series.
* Change default storage type of SharePoint virtual machines to 'StandardSSD_LRS'.
* Change type of parameters to boolean when possible.
* Introduce new parameter 'RDPTrafficAllowed', to finely configure if/how RDP traffic should be allowed.
* Reorder parameters to have a more logical display when deploying the template from the portal.
* Update the list of disk types available for virtual machines.
* Improve management of automatic Windows updates
* Update apiVersion of all resources to latest version.
* Update DSC module SharePointDSC from 4.7 to 4.8, which no longer needs custom changes.
* Update DSC module SqlServerDsc from 15.1.1 to 15.2

## Enhancements & bug-fixes - Published in June 22, 2021

* Reduce deployment time by removing the (no longer needed) workaround that reboots SP VM before creating the site in SharePoint 2019
* Reduce deployment time by enabling the distributed cache service during the SharePoint farm creation (in SP VM only)
* Reduce deployment time by running script UpdateGPOToTrustRootCACert only if necessary
* Install Visual Studio Code in SP and FE VMs
* Create modern team sites instead of classic team sites in SharePoint 2019
* Return various information as output of the template deployment
* Update TLS 1.2 settings in SP and FE VMs
* Enable file sharing (on Domain network profile) also on SQL VM (it is already enabled on SP and FE VMs)
* Update DSC module SharePointDSC from 4.5.1 to 4.7, removed the now useless dependency on ReverseDSC and manually added the changes in PR #1325
* Update DSC module xDnsServer from 1.16.0 to 2.0
* Set local admin name on VM SQL/SP/FE with a unique string, to avoid using the local admin instead of the domain admin

## Enhancements & bug-fixes - Published in March 29, 2021

* Rename local admin on VM SQL/SP/FE to local-'adminUserName', to avoid using the local admin instead of the domain admin
* Set UserPrincipalName of all AD accounts
* Change the identity claim type to use the UPN in federated authentication
* Change the format of the realm / identifier in federated authentication
* Fix the reboot issue on SP and FE VMs when they join the AD domain
* Enable file sharing (on Domain network profile) on SP and FE VMs
* Setup an OIDC application in ADFS
* Add new SQL permissions to spsetup account to work with updated SPFarm resource
* Add a retry download logic to DSC resource cChocoInstaller to improve reliability
* Various improvements in DSC configurations
* Update apiVersion of ARM resources
* Replace outdated DSC module cADFS with AdfsDsc 1.1
* Update DSC module SharePointDSC from 4.3 to 4.5.1
* Update DSC module SqlServerDsc from 15.0 to 15.1.1
* Update DSC module NetworkingDsc from 8.1 to 8.2
* Update DSC module CertificateDsc from 4.7 to 5.1

## Enhancements & bug-fixes - Published in February 9, 2021

* Update DSC module cChoco from 2.4 to 2.5 to fix issue <https://github.com/chocolatey/cChoco/issues/151>

## Enhancements & bug-fixes - Published in December 10, 2020

* Update Chocolatey packages Edge, Notepad++ and Fiddler to their latest version
* Install 7-zip through Chocolatey
* Remove ADFS service account from Administrators group
* Fix the duplicate SPN issue on MSSQLSvc service, which was on both the SQL computer and the SQL service account
* Set the SPN of SharePoint sites on the SharePoint application pool account
* Set property ProviderSignOutUri on resource SPTrustedIdentityTokenIssuer
* Change default size of SP and SQL VMs to Standard_E2ds_v4
* Update DSC module SqlServerDsc from 14.2.1 to 15.0

## Enhancements & bug-fixes - Published in October 13, 2020

* Install Edge Chromium in SharePoint VMs through Chocolatey
* Install Notepad++ in SharePoint VMs through Chocolatey
* Install Fiddler in SharePoint VMs through Chocolatey
* Install ULS Viewer in SharePoint VMs through Chocolatey
* Define the list of all possible values for the time zone parameter vmsTimeZone
* Use a unique location for custom registry keys
* Update DSC module SharePointDSC from 4.2 to 4.3
* Update DSC module NetworkingDsc from 8.0 to 8.1
* Update DSC module ActiveDirectoryCSDsc from 4.1 to 5.0
* Update DSC module xWebAdministration from 3.1.1 to 3.2

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
