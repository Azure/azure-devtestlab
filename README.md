# Azure Lab Services Community

This is a public, community-contributed repository that contains:

- **Artifacts for Azure DevTest Labs:** These [artifacts](https://docs.microsoft.com/en-us/azure/lab-services/devtest-lab-concepts#artifacts) can be deployed onto virtual machines in Azure DevTest Labs via the Azure Portal or through scripts.

- **Environments for Azure DevTest Labs:** An [environment](https://docs.microsoft.com/en-us/azure/lab-services/devtest-lab-concepts#environment) is a collection of resources defined as ARM templates, which represent the [Public Environment](https://azure.microsoft.com/en-ca/updates/azure-devtest-labs-public-environment-repository-in-labs/) repository in Azure DevTest Labs and can be accessed via the Azure Portal or through scripts.

- **Samples for both Azure DevTest Labs and Classroom Labs:** These samples vary from QuickStart Templates, to SDK samples and scripts that can be used to facilitate outside-the-box scenarios. They are used to demonstrate how Azure Lab Services can be integrated in automation scenarios.

- **Azure Pipelines Tasks for Azure DevTest Labs:** This is the source code used to author Azure Pipelines tasks specifically geared to demonstrate use of Azure DevTest Labs in builds/releases. Refer to [Azure DevTest Labs Tasks](https://marketplace.visualstudio.com/items?itemName=ms-azuredevtestlabs.tasks) for more information and to install.


## Azure DevTest Labs PowerShell Module

[Az.DevTestLabs](https://github.com/Azure/azure-devtestlab/tree/master/samples/DevTestLabs/Modules/Library), for short, is a PowerShell module to simplify the management of [Azure DevTest Labs](https://azure.microsoft.com/en-us/services/devtest-lab/). It provides composable functions to create, query, update and delete labs, VMs, Custom Images and Environments. The source can be located under [/samples/DevTestLabs/Modules/Library/](https://github.com/Azure/azure-devtestlab/tree/master/samples/DevTestLabs/Modules/Library).

## Contributions

Contributions are encouraged and welcome. Please refer to the respective sections (e.g. Artifacts, Environments, Tasks) for more details on the respective process to follow.

## Open Source Code of Conduct

This project has adopted the [Microsoft Open Source Code of Conduct](https://opensource.microsoft.com/codeofconduct/). For more information see the [Code of Conduct FAQ](https://opensource.microsoft.com/codeofconduct/faq/) or contact [opencode@microsoft.com](mailto:opencode@microsoft.com) with any additional questions or comments.