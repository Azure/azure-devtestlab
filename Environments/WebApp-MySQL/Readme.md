# Azure Web App with MySQL

Azure Web Apps enable you to build and host web applications in the programming language of your choice without managing infrastructure. It offers auto-scaling and high availability and enable automated deployments from [GitHub](https://github.com), [Azure DevOps](https://azure.microsoft.com/en-ca/services/devops), or any Git repo.

To learn more about Web Apps refer to [App Service overview](https://docs.microsoft.com/en-us/azure/app-service/overview) documentation.

This template creates a Web App with **Azure Database for MySQL Flexible Server**.
It replaces the retired MySQL Single Server resource model for new environments;
it does not migrate existing servers or data.

## Resources and connectivity

- The existing Standard S1 App Service plan and Web App.
- A Burstable `Standard_B1ms` MySQL Flexible Server, MySQL 8.0 (ARM version value
  `8.0.21`), 32 GiB storage with auto-grow, seven-day locally redundant backups,
  and no high availability. Check regional availability and quota before testing.
- A database and an `AllowAzureServices` firewall rule (`0.0.0.0` to `0.0.0.0`).
  Unlike the old allow-all-IPv4 rule, this permits connections originating from
  Azure, including other customers' Azure resources, subject to authentication.
  It is **not** restricted to this Web App and is not private networking.
  Public network access must be permitted by your subscription's policy.
- A `defaultConnection` MySQL connection string in the Web App, using the server's
  returned hostname, the plain administrator login (no `@servername` suffix),
  and `SslMode=VerifyFull`. Use a MySQL client with trusted CA certificates and
  certificate/hostname verification support; do not disable TLS verification.

The password remains a `securestring` input and is stored in the Web App's
connection-string configuration. It is not emitted as a deployment output.
Avoid sharing parameter files, connection strings or unredacted deployment logs.
The Web App has no application code installed by this template.

## Validate and test

1. Use a disposable resource group or an authorized DevTest Lab in a region
   offering the selected MySQL SKU. These resources incur charges, including
   database storage and the S1 App Service plan, until deleted.
2. Before deployment, run ARM validation in the target resource group. With the
   template checked out locally, Azure CLI can prompt for the secure password
   rather than putting it on the command line:

   ```powershell
   az deployment group validate `
   --subscription '<test-subscription-id>' `
   --resource-group '<disposable-resource-group>' `
   --template-file .\Environments\WebApp-MySQL\azuredeploy.json `
   --parameters 'Database Administrator Login=dtltestadmin'
   ```

   Supply the missing administrator password through the interactive prompt.
   Use a strong password meeting MySQL Flexible Server requirements and a
   non-reserved administrator login. Validation does not provision resources
   or prove quota/capacity, firewall connectivity, or successful deployment.

3. To test through DevTest Labs **before merging**, publish the candidate branch
   to an accessible Git repository and add it as a separate artifact source in
   the test lab. Select that exact branch, set its ARM template folder to
   `/Environments`, enable ARM templates, and wait for synchronization. Confirm
   you are selecting this source's **Web App with MySQL** template rather than
   the existing public source, which still reads its configured branch.
4. Create an environment with a unique name and both administrator inputs.
   Verify the real environment PUT is accepted, ARM provisioning reaches
   `Succeeded`, and the Portal displays its terminal creation-success
   notification. Inspect the generated resource group: the database server must
   be `Microsoft.DBforMySQL/flexibleServers`, not `Microsoft.DBforMySQL/servers`.
5. Confirm the database and firewall rule were created and the Web App's
   `defaultConnection` setting exists without copying its password into logs.
   From a MySQL-capable application/client running in that Web App's Azure
   environment, use the configured connection string and execute `SELECT 1`
   against the created database with certificate verification enabled. A green
   ARM deployment alone does not prove database connectivity. A workstation's
   public IP is not allowed by the Azure-services rule.
6. Delete the test environment through DTL and verify its generated resource
   group and billable resources are removed. Remove only the test artifact
   source you added; do not delete the lab or other users' resources. For a
   direct ARM test, delete only the disposable resource group you created.

Updating this template does not change Key Vault networking. A separate
`AccessToKeyVaultForbidden` / `ForbiddenByConnection` error while loading the
DTL form must be resolved independently.
