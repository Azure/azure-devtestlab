# SharePoint 2013 Farm

You can now readily deploy a three-tier SharePoint Server 2013 farm in Azure. This is designed to help you quickly create an Internet-facing SharePoint farm for dev/test, demonstration, or proof-of-concept purposes.

# DSC Configuration files (.zip files)
## Prepare SharePoint Server
- PrepareSharePointServer.ps1
	- A DSC file to add a second disk with the drive letter F, enable ADPS, and add DNSServerAddress with all the supporting modules. 
	- These modules are:
		- cDisk
		- xComputerManagement
		- xDisk
		- xNetworking
## Configure SharePoint Server
- ConfigureSharePointServer.ps1
	- A DSC file to enable CredSSP for WinRM, Domain Join the machine, create and add setup account to admin group, create farm account, and configure SharePoint Server 
		- Modules included:
			- xActiveDirectory
			- xComputerManagement
			- xCredSSP
			- cConfigureSharePoint - created by Simon Davies
## Prepare SQL Server
- PrepareSqlServer.ps1
	- A DSC file to add F (SQL Data) and G (SQL Log) drives, set DB firewall rule, set DNS Server address
		- Modules included:
			- cDisk
			- xComputerManagement
			- xDisk
			- xNetworking
## Configure SQL Server
- ConfigureSqlServer.ps1
	- A DSC file to domain join the machine, create accounts, configure SQL Server, add accounts to roles, and configure SQL login
		- Modules included:
			- xActiveDirectory
			- xComputerManagement
			- xSQL
			- xSqlPs
			- xSQLServer
## Create ADPDC
- CreateADPDC.ps1
	- A DSC file to enable DNS with tools, configure DNS Server, Add F Disk, install AD Domain service and configure.
		- Modules included:
			- cDisk
			- xActiveDirectory
			- xDisk
			- xNetworking 