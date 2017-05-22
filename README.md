# Azure DevTest Labs Community
This is a public, community-contributed repository that contains:
- **Artifacts for Azure DevTest Labs:** These artifacts can be deployed onto VMs in Azure DevTest Labs in the new Azure portal.

- **Azure Resource Manager Quickstart Templates for Azure DevTest Labs:** These templates help with creation and deployment of resources related to Azure DevTest Labs (e.g. Labs, VMs and VM templates etc).
- **Open Source Code of Conduct:** This project has adopted the [Microsoft Open Source Code of Conduct](https://opensource.microsoft.com/codeofconduct/). For more information see the [Code of Conduct FAQ](https://opensource.microsoft.com/codeofconduct/faq/) or contact [opencode@microsoft.com](mailto:opencode@microsoft.com) with any additional questions or comments.

---
### Artifacts Authoring:
- Please see the document ['AUTHORING'](Documentation/AUTHORING.md) in the Documentation folder for details.

Contributions guidelines:
- Every artifact should be contained in its own **folder** under the **Artifacts** folder.

- The artifact definition file should be named **Artifactfile.json**. The name of the artifact that shows up in Azure DevTest Labs is from the title field in the artifact definition.

- All dependencies of the artifact (such as scripts, icons etc) should be included in the artifact folder itself.

- All references to icons must use SSL, otherwise they will not load in the Azure portal.

- It is highly recommended that a **Readme.md** file be included to explain how the artifact works and how to troubleshoot any failures.

- For authors who create the artifact and take responsibility of maintaining it, it is encouraged to add your name in the "publisher" field while authoring artifacts.   


---
### Azure Resource Manager Quickstart Templates
- The latest, *developer* versions of the Azure Resource Manager Quickstart Templates for Azure DevTest Labs can be found in the ['ARMTemplates'](ARMTemplates) folder of this repo.

---
### Miscellaneous

Some useful scripts, related to Azure DevTest labs can be found in the ['scripts'](../../tree/master/Scripts) folder.


