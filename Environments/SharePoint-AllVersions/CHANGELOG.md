# Change log for AzureRM template SharePoint-ADFS-DevTestLabs

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
