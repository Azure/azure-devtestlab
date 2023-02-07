# Azure template for SharePoint 2019 / 2016 / 2013, optimized for DevTest Labs

## Presentation

[![Deploy To Azure](https://raw.githubusercontent.com/Azure/azure-quickstart-templates/master/1-CONTRIBUTION-GUIDE/images/deploytoazure.svg?sanitize=true)](https://portal.azure.com/#create/Microsoft.Template/uri/https%3A%2F%2Fraw.githubusercontent.com%2FAzure%2Fazure-devtestlab%2Fmaster%2FEnvironments%2FSharePoint-AllVersions%2Fazuredeploy.json)
[![Deploy To Azure US Gov](https://raw.githubusercontent.com/Azure/azure-quickstart-templates/master/1-CONTRIBUTION-GUIDE/images/deploytoazuregov.svg?sanitize=true)](https://portal.azure.us/#create/Microsoft.Template/uri/https%3A%2F%2Fraw.githubusercontent.com%2FAzure%2Fazure-devtestlab%2Fmaster%2FEnvironments%2FSharePoint-AllVersions%2Fazuredeploy.json)
[![Visualize](https://raw.githubusercontent.com/Azure/azure-quickstart-templates/master/1-CONTRIBUTION-GUIDE/images/visualizebutton.svg?sanitize=true)](http://armviz.io/#/?load=https%3A%2F%2Fraw.githubusercontent.com%2FAzure%2Fazure-devtestlab%2Fmaster%2FEnvironments%2FSharePoint-AllVersions%2Fazuredeploy.json)

This template deploys SharePoint Subscription, 2019, 2016 and 2013. Each SharePoint version is independent and may or may not be deployed, depending on your needs.  
A DC is provisioned and configured with ADFS and ADCS (both are optional), and a unique SQL Server is provisioned for all SharePoint farms.  
Each SharePoint farm has a lightweight configuration to provision quickly: 1 web application with 1 site collection, using Windows NTLM on Default zone, and optionally ADFS on Intranet zone.

## Remote access and security

The template creates 1 virtual network with 3 subnets (+1 if [Azure Bastion](https://azure.microsoft.com/services/azure-bastion/) is enabled), and each subnet is protected by a [Network Security Group](https://docs.microsoft.com/azure/virtual-network/network-security-groups-overview) which denies all incoming traffic by default.  
The following parameters configure how to connect to the virtual machines, and the level of network security:

- parameters `adminPassword` and `serviceAccountsPassword` require a [strong password](https://learn.microsoft.com/azure/virtual-machines/windows/faq#what-are-the-password-requirements-when-creating-a-vm-).
- parameter `addPublicIPAddress`:
  - if `"SharePointVMsOnly"` (default): Only SharePoint virtual machines get a public IP address with a DNS name and can be reached from Internet.
  - If `"Yes"`: All virtual machines get a public IP address with a DNS name, and can be reached from Internet.
  - if `"No"`: No public IP resource is created.
  - The DNS name format of virtual machines is `"[resourceGroupName]-[vm_name].[region].cloudapp.azure.com"` and is recorded as output in the state file.
- parameter `RDPTrafficAllowed` specifies if RDP traffic is allowed:
  - If `"No"` (default): Firewall denies all incoming RDP traffic.
  - If `"*"` or `"Internet"`: Firewall accepts all incoming RDP traffic from Internet.
  - If CIDR notation (e.g. `"192.168.99.0/24"` or `"2001:1234::/64"`) or IP address (e.g. `"192.168.99.0"` or `"2001:1234::"`): Firewall accepts incoming RDP traffic from the IP addresses specified.
- parameter `addAzureBastion`:
  - if `true`: Configure service [Azure Bastion](https://azure.microsoft.com/services/azure-bastion/) to allow a secure remote access to virtual machines.
  - if `false` (default): Service [Azure Bastion](https://azure.microsoft.com/services/azure-bastion/) is not created.

## Cost of the resources deployed

By default, virtual machines use [B-series burstable](https://docs.microsoft.com/azure/virtual-machines/sizes-b-series-burstable), ideal for such template and much cheaper than other comparable series.  
Here is the default size and storage type per virtual machine role:

- DC: Size [Standard_B2s](https://docs.microsoft.com/azure/virtual-machines/sizes-b-series-burstable) (2 vCPU / 4 GiB RAM) and OS disk is a 32 GiB [standard SSD E4](https://learn.microsoft.com/azure/virtual-machines/disks-types#standard-ssds).
- SQL Server: Size [Standard_B2ms](https://docs.microsoft.com/azure/virtual-machines/sizes-b-series-burstable) (2 vCPU / 8 GiB RAM) and OS disk is a 128 GiB [standard SSD E10](https://learn.microsoft.com/azure/virtual-machines/disks-types#standard-ssds).
- SharePoint: Size [Standard_B4ms](https://docs.microsoft.com/azure/virtual-machines/sizes-b-series-burstable) (4 vCPU / 16 GiB RAM) and OS disk is either a 32 GiB [standard SSD E4](https://learn.microsoft.com/azure/virtual-machines/disks-types#standard-ssds) (for SharePoint Subscription and 2019), or a 128 GiB [standard SSD E10](https://learn.microsoft.com/azure/virtual-machines/disks-types#standard-ssds) (for SharePoint 2016 and 2013).

You can visit <https://azure.com/e/c494029b0b034b8ca356c926dfd2688a> to estimate the monthly cost of the template in the region/currency of your choice, assuming it is created using the default settings and runs 24*7.

## More information

Additional notes:

- Using the default options, the complete deployment takes about 40 minutes.
- Once it is completed, the template will return valuable information in the 'Outputs' of the deployment.
- For various (very good) reasons, in SQL and SharePoint VMs, the name of the local (not domain) administrator is set with a string that is unique to your subscription (e.g. `"local-[q1w2e3r4t5]"`). It is recorded in the 'Outputs' of the deployment once it is completed.

`Tags: Microsoft.Network/networkSecurityGroups, Microsoft.Network/virtualNetworks, Microsoft.Network/publicIPAddresses, Microsoft.Network/networkInterfaces, Microsoft.Compute/virtualMachines, extensions, DSC, Microsoft.Compute/virtualMachines/extensions, Microsoft.DevTestLab/schedules, Microsoft.Network/virtualNetworks/subnets, Microsoft.Network/bastionHosts`
