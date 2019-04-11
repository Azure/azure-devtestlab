Quick-start Instructions:
1. Install Azure Powershell using the link http://aka.ms/webpi-azps
2. Place all the files under the same folder. e.g. C:\DemoLabTemplate
3. Run Windows PowerShell as Administrator
4. In the Windows PowerShell console, go to the folder that stores all these files by running:

	cd "<your folder path>"

   e.g.:
	PS C:\WINDOWS\system32>cd "C:\DemoLabTemplate"

5. Then run the following commands:

	.\ProvisionDemoLab.ps1 -SubscriptionId "<Azure subscription ID where the lab will be created>" -ResourceGroupName "<name for the new resource group where the lab will be created>" -ResourceGroupLocation "<location for the resource group to be created. e.g. West US>"

   e.g.
	PS C:\DemoLabTemplate>.\ProvisionDemoLab.ps1 -SubscriptionId "12345678-1234-5678-1234-123456789000" -ResourceGroupName "FabrikamDevTestDemoLab" -ResourceGroupLocation "West US"

=====================================================================================

About the resources created in the Demo Lab:
The ARM template creates a demo lab with the following things:
* It sets up all the policies and a private artifact repo.
* It creates 3 custom VM images/templates.
* It creates 4 VMs, and 3 of them are created with the new custom VM images/templates.

To customize the lab/VM/template properties (e.g. the lab name), change the parameter values in the azuredeploy.parameters.json file. 
