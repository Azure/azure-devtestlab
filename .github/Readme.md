# Notes

These workflows require the presence of the following secrets in the repo:

. PRINCIPAL_USER
. PRINCIPAL_TENANT
. PRINCIPAL_PASSWORD

You generate these values when you create your Azure Service Principal with the following call:

~~~~powershell
az ad sp create-for-rbac --name YOURNAME --role contributor --scopes /subscriptions/YOURSUBSCRIPTION/resourceGroups/AzLabsLibrary
~~~~
