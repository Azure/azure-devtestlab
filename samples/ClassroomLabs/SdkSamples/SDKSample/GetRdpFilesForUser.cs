using Microsoft.Azure.Management.DevTestLabs;
using Microsoft.Azure.Management.LabServices;
using System;
using System.Collections.Generic;
using System.Configuration;
using System.IO;
using System.Linq;
using System.Threading.Tasks;
using LSEnvironment = Microsoft.Azure.Management.LabServices.Models.Environment;
using LSLabDetails= Microsoft.Azure.Management.LabServices.Models.LabDetails;
using LSEnvironmentDetails= Microsoft.Azure.Management.LabServices.Models.EnvironmentDetails;
using Microsoft.Azure.Management.ResourceManager.Fluent.Core;

namespace SDKSample
{
    internal static class GetRdpFilesForUser
    {
        /// <summary>
        /// Gets all of the expanded environments for a given user and generates RDP files to connect to them.
        /// </summary>
        internal static async Task CreateRdpFiles()
        {
            string userName = ConfigurationManager.AppSettings["UserName"];
            string rdpFolderPath = ConfigurationManager.AppSettings["OutputPath"];
            using (ManagedLabsClient client = new ManagedLabsClient(new CustomLoginCredentials(), new System.Net.Http.HttpClient() { BaseAddress = new Uri("https://management.azure.com") }, true))
            {
                // Get all VMs within the lab
                List<(LSLabDetails, LSEnvironmentDetails)> labEnvPairs = new List<(LSLabDetails, LSEnvironmentDetails)>();
                foreach (LSLabDetails labDetails in (await client.GlobalUsers.ListLabsAsync(userName).ConfigureAwait(false)).Labs)
                {
                    foreach (LSEnvironmentDetails tempenvironment in (await client.GlobalUsers.ListEnvironmentsAsync(userName, new Microsoft.Azure.Management.LabServices.Models.ListEnvironmentsPayload(labDetails.Id)).ConfigureAwait(false)).Environments)
                    {
                        labEnvPairs.Add((labDetails, tempenvironment));
                    }
                }

                // For each Environment, do an expand on the network interface to get RDP info
                List<LSEnvironment> expandedEnvironments = new List<LSEnvironment>();
                foreach ((LSLabDetails lab, LSEnvironmentDetails env) in labEnvPairs)
                {
                    ResourceId labId = ResourceId.FromString(lab.Id);
                    ResourceId envId = ResourceId.FromString(env.Id);
                    client.SubscriptionId = labId.SubscriptionId;
                    expandedEnvironments.Add(await client.Environments.GetAsync(labId.ResourceGroupName, labId.Parent.Name, labId.Name, envId.Parent.Name, envId.Name, "properties($expand=networkInterface)").ConfigureAwait(false));
                }

                // Generate RDP files
                foreach (LSEnvironment env in expandedEnvironments)
                {
                    GenerateRdpFile(env.NetworkInterface.RdpAuthority, env.NetworkInterface.Username, rdpFolderPath, env.Name);
                }
            }
        }

        private static void GenerateRdpFile(string rdpAuthority, string userName, string rdpFolderPath, string rdpFileName)
        {
            string fileContent = "full address:s:" + rdpAuthority +
              "\n" + "prompt for credentials:i:1" + "\n" + "username:s:" + "~\\" + userName;
            string fileName = Path.Combine(rdpFolderPath, rdpFileName + ".rdp");
            File.WriteAllText(fileName, fileContent);
        }
    }
}
