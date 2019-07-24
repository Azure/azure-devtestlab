# Change log for AzureRM template SharePoint-ADFS-DevTestLabs

## July 2019 update

* Add the certificate of the domain root authority to the SPTrustedRootAuthority
* Use DSC resource xWebsite instead of xScript to configure HTTPS binding
* Update DSC module SharePointDSC to 3.5 with customization to add new resource SPTrustedSecurityTokenIssuer and fix SPTrustedRootAuthority
* Update DSC module xPSDesiredStateConfiguration to 8.8, wich a customization on resource xRemoteFile to deal with random connection errors while downloading LDAPCP
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

## March 2019 update

* Initial release
