using Microsoft.Azure.Management.DevTestLabs;
using Microsoft.Azure.Management.LabServices;
using Microsoft.Azure.Management.ResourceManager.Fluent.Core;
using System.Collections.Generic;
using System.Configuration;
using System.Threading.Tasks;
using LSEnvironment = Microsoft.Azure.Management.LabServices.Models.Environment;
using LSEnvironmentDetails = Microsoft.Azure.Management.LabServices.Models.EnvironmentDetails;
using LSLabDetails = Microsoft.Azure.Management.LabServices.Models.LabDetails;

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
            using (IManagedLabsClient client = Utilities.CreateManagedLabsClient())
            {
                // Get all VMs within the lab
                List<(LSLabDetails, LSEnvironmentDetails)> labEnvPairs = new List<(LSLabDetails, LSEnvironmentDetails)>();
                foreach (LSLabDetails labDetails in (await client.GlobalUsers.ListLabsAsync(userName)).Labs)
                {
                    foreach (LSEnvironmentDetails tempenvironment in (await client.GlobalUsers.ListEnvironmentsAsync(userName, new Microsoft.Azure.Management.LabServices.Models.ListEnvironmentsPayload(labDetails.Id))).Environments)
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
                    expandedEnvironments.Add(await client.Environments.GetAsync(labId.ResourceGroupName, labId.Parent.Name, labId.Name, envId.Parent.Name, envId.Name, "properties($expand=networkInterface)"));
                }

                // Generate RDP files
                foreach (LSEnvironment env in expandedEnvironments)
                {
                    Utilities.GenerateRdpFile(env.NetworkInterface.RdpAuthority, env.NetworkInterface.Username, rdpFolderPath, env.Name);
                }
            }
        }
    }
}
