# PAVC

Installs specific version of PAVC from a defined NugGt Feed.

## Prerequisites

- [Azure AD Application & Service Principal][how-to-create-aad-app-and-sp].
- Valid Azure Subscription.
- AzureRM should be installed on the VM.
- Valid white listed PAVC certificate and private key.
- Azure DevOps Service account.
- Service Account PAT scoped only for **vso.packaging**.

## Setup
1. Create AAD App.
2. Create service principal for the App.
3. Grant the AAD App read only access to the subscription where the DevTest Labs instance is created.
4. Create the AAD App Secret/Certificate Get+List access to the KeyVault where the secrets are going to be imported.
5. Upload the PAVC .pfx certificate to the KeyVault and set a meaningful name. It will be later used in the DevTest Labs Artifact.
6. Create a KeyVault secret entry for the PAVC certificate password and set a meaningful name. It will be later used in the DevTest Labs Artifact.
7. Create a KeyVault secret entry for the Service Account PAT and set a meaningful name. It will be later used in the DevTest Labs Artifact.
8. Create the following Secrets in DevTest Labs:
    - tenantId: This is the AAD tenant id.
    - applicationId: This is the ID of the App.
    - servicePrincipalPassword: The Service Principal App password.

## Artifact Parameters

- **Tenant ID**: DevTest Labs secret for the Tenant ID.
- **Application ID**: DevTest Labs secret for the App ID.
- **Service Principal Password**: DevTest Labs secret for the Principal Password.
- **KeyVault Name**: The KeyVault name where the  certificate, certificate password and service account PAT are stored.
- **PAVC KeyVault Certificate name**: The PAVC Certificate name from the KeyVault. Used by the PAVC installation.
- **PAVC KeyVault Certificate Password Key name**: The PAVC Certificate Password Key name from the KeyVault. Used by the PAVC installation.
- **Service Account Name**: The Azure DevOps Service Account Name used to access the PAVC NuGet Feed.
- **KeyVault Service Account PAT Key name**: The Service Account PAT Key name from the KeyVault. Used to authenticate to the NuGet feed where the PAVC package is stored.
- **NuGet Version**: The NuGet Version to download.
- **PAVC NuGet Feed**: The PAVC NuGet Feed. i.e. https://xxx.pkgs.visualstudio.com/_packaging/xxx/nuget/v3/index.json
- **PAVC NuGet Package name**: The PAVC NuGet Package name.
- **PAVC Version**: The PAVC Version to download.
- **PAVC Workload**: The PAVC Workload. PAVC specific setting required during installation. Please contact your security expert for more information.
- **PAVC ServiceLine**: The PAVC ServiceLine. PAVC specific setting required during installation. Please contact your security expert for more information.
- **PAVC CertificateNameWildCard**: The PAVC CertificateNameWildCard. PAVC specific setting required during installation. Please contact your security expert for more information.
- **PAVC Environment**: The PAVC Environment. PAVC specific setting required during installation. Please contact your security expert for more information.
- **PAVC CPURateLimit**: The PAVC CPURateLimit. PAVC specific setting required during installation. Please contact your security expert for more information.
- **PAVC ScanStartTime**: The PAVC ScanStartTime. PAVC specific setting required during installation. Please contact your security expert for more information.

[how-to-create-aad-app-and-sp]: https://docs.microsoft.com/en-us/azure/active-directory/develop/howto-create-service-principal-portal