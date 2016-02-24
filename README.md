# Azure DevTest Lab Community
This is a public, community-contributed repository that contains:
- **Artifacts for Azure DevTest Labs:** These artifacts can be deployed onto VMs in Azure DevTest Labs in the new Azure portal.

- **Azure RM templates for Azure DevTest Labs:** These templates help with creation and deployment of resources related to Azure DevTest Labs (e.g. Labs, VMs and VM templates etc).

---
### Artifacts Authoring:
- Please see the document ['AUTHORING'](Documentation/AUTHORING.md) in the Documentation folder for details.

Contributions guidelines:
- Every artifact should be contained in its own **folder** under the **Artifacts** folder.

- The artifact definition file should be named **Artifactfile.json**. The name of the artifact that shows up in Azure DevTest Labs is from the title field in the artifact definition.

- All dependencies of the artifact (such as scripts, icons etc) should be included in the artifact folder itself.

- It is highly recommended that a **Readme.md** file be included to explain how the artifact works and how to troubleshoot any failures.

---
### Azure RM Templates
- The latest, *developer* versions of the Azure RM Templates for Azure DevTest Labs can be found in the ['RMTemplates'](RMTemplates) folder of this repo.

---
### Miscellaneous

Some useful scripts, related to Azure DevTest labs can be found in the ['scripts'](scripts) folder.
