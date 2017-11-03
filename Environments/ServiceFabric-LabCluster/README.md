# Service Fabric Lab Cluster (Windows/Linux)

This environment template supports to operation modes:

* **Windows** - This mode allows you to deploy a secure 5 node, Single Node Type Service Fabric Cluster running Windows Server 2016 Datacenter on a Standard_D2 Size VMSS with Azure Diagnostics turned on.

* **Linux** - This mode allows you to deploy a secure 5 node, Single Node Type Service fabric Cluster running Ubuntu 16.04 on Standard_D2 Size VMs with Windows Azure diagnostics turned on.

To create the required certificate information for a Service Fabric Secure Cluster please use the [Create-ClusterCertificate.ps1](https://github.com/Azure/azure-devtestlab/tree/master/Environments/ServiceFabric-LabCluster/Create-ClusterCertificate.ps1)  Powershell script.