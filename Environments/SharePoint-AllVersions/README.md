# Azure template for SharePoint 2019 / 2016, optimized for DevTest Labs

## Presentation

[![Deploy To Azure](https://raw.githubusercontent.com/Azure/azure-quickstart-templates/master/1-CONTRIBUTION-GUIDE/images/deploytoazure.svg?sanitize=true)](https://portal.azure.com/#create/Microsoft.Template/uri/https%3A%2F%2Fraw.githubusercontent.com%2FAzure%2Fazure-devtestlab%2Fmaster%2FEnvironments%2FSharePoint-AllVersions%2Fazuredeploy.json)
[![Deploy To Azure US Gov](https://raw.githubusercontent.com/Azure/azure-quickstart-templates/master/1-CONTRIBUTION-GUIDE/images/deploytoazuregov.svg?sanitize=true)](https://portal.azure.us/#create/Microsoft.Template/uri/https%3A%2F%2Fraw.githubusercontent.com%2FAzure%2Fazure-devtestlab%2Fmaster%2FEnvironments%2FSharePoint-AllVersions%2Fazuredeploy.json)
[![Visualize](https://raw.githubusercontent.com/Azure/azure-quickstart-templates/master/1-CONTRIBUTION-GUIDE/images/visualizebutton.svg?sanitize=true)](http://armviz.io/#/?load=https%3A%2F%2Fraw.githubusercontent.com%2FAzure%2Fazure-devtestlab%2Fmaster%2FEnvironments%2FSharePoint-AllVersions%2Fazuredeploy.json)

This template deploys SharePoint Subscription, 2019 and 2016. Each SharePoint version is independent and may or may not be deployed, depending on your needs.  
A DC is provisioned and configured with ADFS and ADCS (both are optional), and a unique SQL Server is provisioned for all SharePoint farms.  
Each SharePoint farm has a lightweight configuration to provision quickly: 1 web application with 1 site collection, using Windows NTLM on Default zone, and optionally ADFS on Intranet zone.

## Outbound access to internet

During the provisionning, virtual machines require an outbound access to internet to be able to download and apply their configuration, so they each get a [Public IP](https://learn.microsoft.com/en-us/azure/virtual-network/ip-services/virtual-network-public-ip-address), associated to their network card.

## Remote access

The remote access to the virtual machines depends on the following parameters:

- Parameter `rdpTrafficRule` specifies if a rule in the network security groups should allow the inbound RDP traffic:
    - `No` (default): No rule is created, RDP traffic is blocked.
    - `*` or `Internet`: RDP traffic is allowed from everywhere.
    - CIDR notation (e.g. `192.168.99.0/24` or `2001:1234::/64`) or an IP address (e.g. `192.168.99.0` or `2001:1234::`): RDP traffic is allowed from the IP address / pattern specified.
- Parameter `enable_azure_bastion`:
  - if `true`: Configure service [Azure Bastion](https://azure.microsoft.com/services/azure-bastion/) to allow a secure remote access to virtual machines.
  - if `false` (default): Service [Azure Bastion](https://azure.microsoft.com/services/azure-bastion/) is not created.

## Input parameters

- Parameter `provisionSharePointSubscription` lets you choose which version of SharePoint Subscription to install:
  - `Subscription-Latest` (default): Same as `Subscription-RTM`, then installs the latest cumulative update available at the time of publishing this version: December 2024 ([KB5002658](https://support.microsoft.com/help/5002658)).
  - `Subscription-24H2`: Same as `Subscription-RTM`, then installs the [Feature Update 24H2](https://learn.microsoft.com/en-us/sharepoint/what-s-new/new-and-improved-features-in-sharepoint-server-subscription-edition-24h2-release) (September 2024 CU / [kb5002640](https://support.microsoft.com/help/5002640)).
  - `Subscription-24H1`: Same as `Subscription-RTM`, then installs the [Feature Update 24H1](https://learn.microsoft.com/en-us/sharepoint/what-s-new/new-and-improved-features-in-sharepoint-server-subscription-edition-24h1-release) (March 2024 CU / [KB5002564](https://support.microsoft.com/help/5002564)).
  - `Subscription-23H2`: Same as `Subscription-RTM`, then installs the [Feature Update 23H2](https://learn.microsoft.com/en-us/SharePoint/what-s-new/new-and-improved-features-in-sharepoint-server-subscription-edition-23h2-release) (September 2023 CU / [KB5002474](https://support.microsoft.com/help/5002474)).
  - `Subscription-23H1`: Same as `Subscription-RTM`, then installs the [Feature Update 23H1](https://learn.microsoft.com/en-us/sharepoint/what-s-new/new-and-improved-features-in-sharepoint-server-subscription-edition-23h1-release) (March 2023 CU / [KB5002355](https://support.microsoft.com/help/5002355)).
  - `Subscription-22H2`: Same as `Subscription-RTM`, then installs the [Feature Update 22H2](https://learn.microsoft.com/en-us/sharepoint/what-s-new/new-and-improved-features-in-sharepoint-server-subscription-edition-22h2-release) (September 2022 CU / [KB5002270](https://support.microsoft.com/help/5002270) and [KB5002271](https://support.microsoft.com/help/5002271)).
  - `Subscription-RTM`: Uses a fresh Windows Server 2022 image, on which SharePoint Subscription RTM is downloaded and installed.
  - `No`: No SharePoint Subscription RTM farm is created.
- Parameter `enableHybridBenefitServerLicenses` allows you to enable Azure Hybrid Benefit to use your on-premises Windows Server licenses and reduce cost, if you are eligible. See [this page](https://docs.microsoft.com/azure/virtual-machines/windows/hybrid-use-benefit-licensing) for more information..

## Cost of the resources deployed

By default, virtual machines use [Basv2 series](https://learn.microsoft.com/azure/virtual-machines/sizes/general-purpose/basv2-series), ideal for such template and much cheaper than other comparable series.  
Here is the default size and storage type per virtual machine role:

- DC: Size [Standard_B2als_v2](https://learn.microsoft.com/azure/virtual-machines/sizes/general-purpose/basv2-series) (2 vCPU / 4 GiB RAM) and OS disk is a 32 GiB [standard SSD E4](https://learn.microsoft.com/azure/virtual-machines/disks-types#standard-ssds).
- SQL Server: Size [Standard_B2as_v2](https://learn.microsoft.com/azure/virtual-machines/sizes/general-purpose/basv2-series) (2 vCPU / 8 GiB RAM) and OS disk is a 128 GiB [standard SSD E10](https://learn.microsoft.com/azure/virtual-machines/disks-types#standard-ssds).
- SharePoint: Size [Standard_B4as_v2](https://learn.microsoft.com/azure/virtual-machines/sizes/general-purpose/basv2-series) (4 vCPU / 16 GiB RAM) and OS disk is a 128 GiB [standard SSD E10](https://learn.microsoft.com/azure/virtual-machines/disks-types#standard-ssds) (for SharePoint Subscription SharePoint 2016), or a 32 GiB [standard SSD E4](https://learn.microsoft.com/azure/virtual-machines/disks-types#standard-ssds) (for SharePoint 2019).

You can visit <https://azure.com/e/85a8cce1b07246df85a16695020854af> to estimate the monthly cost of the template in the region/currency of your choice, assuming it is created using the default settings and runs 24*7.

## Known issues

- When deploying SharePoint 2016 or 2019, the trial enterprise license has already expired, so you must enter your own in the central administration, then run iisreset and restart the SPTimerV4 service on all the servers.
- When deploying SharePoint 2016 or 2019, the installation of softwares through Chocolatey fails for most of them.

## More information

Additional notes:

- Using the default options, the complete deployment takes about 40 minutes (but it is worth it).
- Deploying any post-RTM SharePoint Subscription build adds only an extra 5-10 minutes to the total deployment time (compared to RTM), partly because the updates are installed before the farm is created.
- Once it is completed, the template will return valuable information in the 'Outputs' of the deployment.
- For various (very good) reasons, in SQL and SharePoint VMs, the name of the local (not domain) administrator is set with a string that is unique to your subscription (e.g. `"local-[q1w2e3r4t5]"`). It is recorded in the 'Outputs' of the deployment once it is completed.

`Tags: Microsoft.Network/networkSecurityGroups, Microsoft.Network/virtualNetworks, Microsoft.Network/publicIPAddresses, Microsoft.Network/networkInterfaces, Microsoft.Compute/virtualMachines, extensions, DSC, Microsoft.Compute/virtualMachines/extensions, Microsoft.DevTestLab/schedules, Microsoft.Network/virtualNetworks/subnets, Microsoft.Network/bastionHosts`
