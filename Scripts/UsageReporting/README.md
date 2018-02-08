# Azure DevTest Labs - Usage Reporting
This template includes:


- Azure Storage account where the DevTest Lab usage data request will store the daily data.
- Azure SQL Server with database.
- Azure Automation account with runbooks.
    - Two runbooks, a modules, and various variables are imported.

There are a few items that will need to be executed manually.

-  ###Create RunAs Account
	-  In the Azure Automation Account
	-  Select Account Settings/Run As Accounts
	-  Create the Azure Run As Account
		-  This service principal controls which subscriptions will be checked for DevTest Labs.


- ###Update the Azure modules
	- Open the Resource Group in the Azure Portal.
	- Open the Azure Automation Account and select the Shared Resources/Modules in the left blade.
	- On the top bar run "Update Azure Modules".


##To have the automation execute on a regular basis.
- ###Setup Scheduling
    - In the Azure Automation Account, select Shared Resource/Schedules.
    - Create two schedules one for requesting the data, a second to move the data from storage to SQL.
    - Recommended that the transfer is schedule after you expect the first to complete. 
- ###Link Schedule to Runbooks
    - Open the individual runbooks and select Schedule from the top bar and link the appropriate schedule.

##To setup the included PowerBI dashboard using PowerBI desktop.
- Using the Azure Portal open the Query Editor for the TestTelemetry database
	- Open the TestTelemetry.sql file in the editor and run it, this will create the infrastructure. 
- Copy .pbix locally
- Set the SQL Server firewall settings to allow access to the IP where the local dashboard is.
- Set the DataSource
    - Open the PowerBI file in the PowerBI Desktop version.
    - Under the Edit Queries button, select Data Source Settings.
    - In the Data Source window select Change Sources.
    - Enter the Azure Server name ie servername.database.windows.net,1433
    - Ok, Close, Apply changes will show the SQL Server database connection window
    - Select the database tab and enter the username and password.
    - PowerBI will automatically connect.




## Deployment
<a href="https://portal.azure.com/#create/Microsoft.Template/uri/https%3A%2F%2Fraw.githubusercontent.com%2FAzure%2Fazure-devtestlab%2FusageReporting%2FScripts%2FUsageReporting%2Fazuredeploy.json" target="_blank">
    <img src="http://azuredeploy.net/deploybutton.png"/>
</a>
<a href="http://armviz.io/#/?load=https%3A%2F%2Fraw.githubusercontent.com%2FAzure%2Fazure-devtestlab%2FusageReporting%2FScripts%2FUsageReporting%2Fazuredeploy.json" target="_blank">
    <img src="http://armviz.io/visualizebutton.png"/>
</a>