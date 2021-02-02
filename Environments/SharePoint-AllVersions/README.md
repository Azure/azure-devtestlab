# Azure template for SharePoint 2019 / 2016 / 2013, optimized for DevTest Labs

[![Deploy To Azure](https://raw.githubusercontent.com/Azure/azure-quickstart-templates/master/1-CONTRIBUTION-GUIDE/images/deploytoazure.svg?sanitize=true)](https://portal.azure.com/#create/Microsoft.Template/uri/https%3A%2F%2Fraw.githubusercontent.com%2FAzure%2Fazure-devtestlab%2Fmaster%2FEnvironments%2FSharePoint-AllVersions%2Fazuredeploy.json)
[![Deploy To Azure US Gov](https://raw.githubusercontent.com/Azure/azure-quickstart-templates/master/1-CONTRIBUTION-GUIDE/images/deploytoazuregov.svg?sanitize=true)](https://portal.azure.us/#create/Microsoft.Template/uri/https%3A%2F%2Fraw.githubusercontent.com%2FAzure%2Fazure-devtestlab%2Fmaster%2FEnvironments%2FSharePoint-AllVersions%2Fazuredeploy.json)
[![Visualize](https://raw.githubusercontent.com/Azure/azure-quickstart-templates/master/1-CONTRIBUTION-GUIDE/images/visualizebutton.svg?sanitize=true)](http://armviz.io/#/?load=https%3A%2F%2Fraw.githubusercontent.com%2FAzure%2Fazure-devtestlab%2Fmaster%2FEnvironments%2FSharePoint-AllVersions%2Fazuredeploy.json)

This template deploys SharePoint 2019, 2016 and 2013. Each SharePoint version is independent and may or may not be deployed, depending on your needs.  
A DC is provisioned and configured with ADFS and ADCS (both are optional), and a unique SQL Server is provisioned for all SharePoint farms.  
Each SharePoint farm has a lightweight configuration to provision quickly: 1 web application with 1 site collection, using Windows NTLM on Default zone, and optionally ADFS on Intranet zone.

All subnets are protected by a Network Security Group with rules that restrict network access. You can connect to virtual machines using:

* [Azure Bastion](https://azure.microsoft.com/en-us/services/azure-bastion/) if you set parameter addAzureBastion to 'Yes'.
* RDP protocol if you set parameter addPublicIPToVMs to 'Yes'. Each machine will have a public IP, a DNS name, and the TCP port 3389 will be allowed from Internet.

By default, virtual machines use standard storage and are sized with a good balance between cost and performance:

* Virtual machine size for DC: [Standard_DS2_v2](https://docs.microsoft.com/en-us/azure/virtual-machines/dv2-dsv2-series): 2 CPU / 7 GiB RAM with HDD ($183.96/month in West US as of 2020-08-12)
* Virtual machine size for SQL Server: [Standard_E2ds_v4](https://docs.microsoft.com/en-us/azure/virtual-machines/edv4-edsv4-series): 2 CPU / 16 GiB RAM with HDD ($185.42/month in West US as of 2020-08-12)
* Virtual machine size for SharePoint: [Standard_E2ds_v4](https://docs.microsoft.com/en-us/azure/virtual-machines/edv4-edsv4-series): 2 CPU / 16 GiB RAM with HDD ($185.42/month in West US as of 2020-08-12)

If you need a boost in performance, you may consider the following sizes / storage account types:

* Virtual machine size for DC: [Standard_DS2_v2](https://docs.microsoft.com/en-us/azure/virtual-machines/dv2-dsv2-series): 2 CPU / 7 GiB RAM with HDD ($183.96/month in West US as of 2020-08-12)
* Virtual machine size for SQL Server: [Standard_E2as_v4](https://docs.microsoft.com/en-us/azure/virtual-machines/eav4-easv4-series): 2 CPU / 16 GiB RAM with SSD ($169.36/month in West US as of 2020-08-12)
* Virtual machine size for SharePoint: [Standard_E4as_v4](https://docs.microsoft.com/en-us/azure/virtual-machines/eav4-easv4-series): 4 CPU / 32 GiB RAM with SSD ($338.72/month in West US as of 2020-08-12)
