# Azure DevTest Lab Community
This is a public, community-contributed repository that contains:
- **Artifacts for Azure DevTest Labs:** These artifacts can be deployed onto VMs in Azure DevTest Labs in the new Azure portal ([more details](#artifacts)).

- **Azure RM templates for Azure DevTest Labs:** These templates help with creation and deployment of resources related to Azure DevTest Labs (e.g. Labs, VMs and VM templates etc) ([more details](#azure-rm-templates)).

- **PowerShell module for Azure DevTest Labs:** Cmdlets for accessing and creating Azure DevTest Lab resources like labs, VMs, VM templates etc ([more details](#powershell-module)).

---
### Artifacts [![Build Status](http://dtl-internal-ci.westus.cloudapp.azure.com:8080/job/Regression-Tests-Artifacts/badge/icon?style=plastic)](http://dtl-internal-ci.westus.cloudapp.azure.com:8080/job/Regression-Tests-Artifacts/)
Authoring:
- Please see the document ['AUTHORING'](Documentation/AUTHORING.md) in the Documentation folder for details.

Contributions guidelines:
- Every artifact should be contained in its own **folder** under the **Artifacts** folder.

- The artifact definition file should be named **Artifactfile.json**. The name of the artifact that shows up in Azure DevTest Labs is from the title field in the artifact definition.

- All dependencies of the artifact (such as scripts, icons etc) should be included in the artifact folder itself.

- It is highly recommended that a **Readme.md** file be included to explain how the artifact works and how to troubleshoot any failures.

---
### Azure RM Templates [![Build Status](http://dtl-internal-ci.westus.cloudapp.azure.com:8080/job/Regression-Tests-ARMTemplates/badge/icon?style=plastic)](http://dtl-internal-ci.westus.cloudapp.azure.com:8080/job/Regression-Tests-ARMTemplates/)
Downloads:
- The official, stable versions can be found in [Azure quickstart template repository](https://github.com/Azure/azure-quickstart-templates).

- The latest, *developer* versions can be found in the ['RM Templates'](RM Templates) folder of this repo.

---
### PowerShell Module [![Build Status](http://dtl-internal-ci.westus.cloudapp.azure.com:8080/job/Regression-Tests-PowerShell/badge/icon?style=plastic)](http://dtl-internal-ci.westus.cloudapp.azure.com:8080/job/Regression-Tests-PowerShell/)
Source:
- The source code for AzureRM.DevTestLab can be found in the ['PowerShell'](powershell) folder.

Installation Steps:
- [Prerequisite] Azure PowerShell.
  - Install the [Web Platform Installer](http://www.microsoft.com/web/downloads/platform.aspx).
  - Launch the Web Platform Installer and install the **latest** version of Azure PowerShell.
- Import the AzureRM.DevTestLab cmdlets
  - Clone this repo on your machine.
  - Open PowerShell console (or PowerShell_ISE) as admin and run the following commands:
    - cd [path to local repo]\\PowerShell\\AzureRM.DevTestLab
    - Import-Module .\\PublishCmdlets.ps1
    - Update-RMTemplates
    - Import-Module .\\AzureRM.DevTestLab.ps1 -Verbose

Coming Soon:
- The AzureRM.DevTestLab module Labs will soon be installable directly from the [PowerShell gallery](https://www.powershellgallery.com).

---
### Miscellaneous

Some useful scripts, related to Azure DevTest labs can be found in the ['scripts'](scripts) folder.
