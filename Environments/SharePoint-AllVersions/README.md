# Azure template for SharePoint 2019 / 2016 / 2013, optimized for DevTest Labs

## Presentation

[![Deploy To Azure](https://raw.githubusercontent.com/Azure/azure-quickstart-templates/master/1-CONTRIBUTION-GUIDE/images/deploytoazure.svg?sanitize=true)](https://portal.azure.com/#create/Microsoft.Template/uri/https%3A%2F%2Fraw.githubusercontent.com%2FAzure%2Fazure-devtestlab%2Fmaster%2FEnvironments%2FSharePoint-AllVersions%2Fazuredeploy.json)
[![Deploy To Azure US Gov](https://raw.githubusercontent.com/Azure/azure-quickstart-templates/master/1-CONTRIBUTION-GUIDE/images/deploytoazuregov.svg?sanitize=true)](https://portal.azure.us/#create/Microsoft.Template/uri/https%3A%2F%2Fraw.githubusercontent.com%2FAzure%2Fazure-devtestlab%2Fmaster%2FEnvironments%2FSharePoint-AllVersions%2Fazuredeploy.json)
[![Visualize](https://raw.githubusercontent.com/Azure/azure-quickstart-templates/master/1-CONTRIBUTION-GUIDE/images/visualizebutton.svg?sanitize=true)](http://armviz.io/#/?load=https%3A%2F%2Fraw.githubusercontent.com%2FAzure%2Fazure-devtestlab%2Fmaster%2FEnvironments%2FSharePoint-AllVersions%2Fazuredeploy.json)

This template deploys SharePoint 2019, 2016 and 2013. Each SharePoint version is independent and may or may not be deployed, depending on your needs.  
A DC is provisioned and configured with ADFS and ADCS (both are optional), and a unique SQL Server is provisioned for all SharePoint farms.  
Each SharePoint farm has a lightweight configuration to provision quickly: 1 web application with 1 site collection, using Windows NTLM on Default zone, and optionally ADFS on Intranet zone.

## Remote access and security

The template creates 1 virtual network with 3 subnets. All subnets are protected by a [Network Security Group](https://docs.microsoft.com/en-us/azure/virtual-network/network-security-groups-overview) with no custom rule by default.

The following parameters impact the remote access of the virtual machines, and the network security:

* Parameter 'addPublicIPAddressToEachVM':
  * if true (default value): Each virtual machine gets a public IP, a DNS name, and may be reachable from Internet.
  * if false: No public IP resource is created.
* Parameter 'RDPTrafficAllowed':
  * If 'No' (default value): Firewall denies all incoming RDP traffic from Internet.
  * If '*' or 'Internet': Firewall accepts all incoming RDP traffic from Internet.
  * If 'ServiceTagName': Firewall accepts all incoming RDP traffic from the specified 'ServiceTagName'.
  * If 'xx.xx.xx.xx': Firewall accepts incoming RDP traffic only from the IP 'xx.xx.xx.xx'.
* Parameter 'addAzureBastion':
  * if true: Configure service [Azure Bastion](https://azure.microsoft.com/en-us/services/azure-bastion/) to allow a secure remote access.
  * if false (default value): Service Azure Bastion is not created.

## Cost

By default, virtual machines use [B-series burstable](https://docs.microsoft.com/en-us/azure/virtual-machines/sizes-b-series-burstable), ideal for such template and much cheaper than other comparable series.  
Here is the default size and storage type per virtual machine role:

* DC: Size [Standard_B2s](https://docs.microsoft.com/en-us/azure/virtual-machines/sizes-b-series-burstable) (2 vCPU / 4 GiB RAM) and OS disk is a 32 GiB standard HDD.
* SQL Server: Size [Standard_B2ms](https://docs.microsoft.com/en-us/azure/virtual-machines/sizes-b-series-burstable) (2 vCPU / 8 GiB RAM) and OS disk is a 128 GiB standard HDD.
* SharePoint: Size [Standard_B4ms](https://docs.microsoft.com/en-us/azure/virtual-machines/sizes-b-series-burstable) (4 vCPU / 16 GiB RAM) and OS disk is a 128 GiB [standard SSD](https://azure.microsoft.com/en-us/blog/preview-standard-ssd-disks-for-azure-virtual-machine-workloads/).

You can visit <https://azure.com/e/a2349269adde449396e4a39163692ec1> to view the global cost of the template when it is deployed using the default settings, in the region/currency of your choice.

## More information

Additional notes:

* I strongly recommend to update SharePoint to a recent build after the deployment completed.  
* With the default settings, the deployment takes about 40 minutes to complete.  
* Once it is completed, the template will return valuable information in the 'Outputs' of the deployment.  
* For various (very good) reasons, the template sets the local (not domain) administrator name with a string that is unique to your subscription (e.g. 'local-q1w2e3r4t5'). You can find the name of the local admin in the 'Outputs' of the deployment once it is completed.  
