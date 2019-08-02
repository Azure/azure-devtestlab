using Microsoft.Azure.Management.DevTestLabs;
using Microsoft.Azure.Management.LabServices;
using System;
using System.Collections.Generic;
using System.Configuration;
using System.IO;
using System.Linq;
using System.Reflection.Emit;
using System.Threading.Tasks;
using LSEnvironment = Microsoft.Azure.Management.LabServices.Models.Environment;
using LSEnvironmentSetting = Microsoft.Azure.Management.LabServices.Models.EnvironmentSetting;

namespace SDKSample
{
    internal static class GetPrivateRdpFilesForLab
    {
        /// <summary>
        /// Gets all of the expanded environments for a given Lab and generates RDP files to connect to them.
        /// </summary>
        internal static async Task CreateRdpFiles()
        {
            string resourceGroupName = ConfigurationManager.AppSettings["ResourceGroupName"];
            string labAccountName = ConfigurationManager.AppSettings["LabAccountName"];
            string labName = ConfigurationManager.AppSettings["LabName"];
            string rdpFolderPath = ConfigurationManager.AppSettings["OutputPath"];
            using (ManagedLabsClient client = new ManagedLabsClient(new CustomLoginCredentials(), new System.Net.Http.HttpClient() { BaseAddress = new Uri("https://management.azure.com") }, true) { SubscriptionId = ConfigurationManager.AppSettings["SubscriptionId"] })
            {
                // Get all VMs within the lab
                List<(LSEnvironmentSetting, LSEnvironment)> envSettingEnvPairs = new List<(LSEnvironmentSetting, LSEnvironment)>();
                foreach (LSEnvironmentSetting envSetting in (await client.EnvironmentSettings.ListAsync(resourceGroupName, labAccountName, labName).ConfigureAwait(false)))
                {
                    foreach (LSEnvironment tempenvironment in await client.Environments.ListAsync(resourceGroupName, labAccountName, labName, envSetting.Name).ConfigureAwait(false))
                    {
                        envSettingEnvPairs.Add((envSetting, tempenvironment));
                    }
                }

                // For each Environment, do an expand on the network interface to get RDP info
                LSEnvironment[] expandedEnvironments = await Task.WhenAll(
                    envSettingEnvPairs.Select(envtuple =>
                    client.Environments.GetAsync(resourceGroupName, labAccountName, labName, envtuple.Item1.Name, envtuple.Item2.Name, "properties($expand=networkInterface)")))
                    .ConfigureAwait(false);

                // Generate RDP files
                Dictionary<string, HashSet<string>> uniquePublicIPs = new Dictionary<string, HashSet<string>>();

                foreach (LSEnvironment env in expandedEnvironments)
                {
                    string[] rdpAuth = env.NetworkInterface.RdpAuthority.Split(':');
                    if (!uniquePublicIPs.ContainsKey(rdpAuth[0]))
                    {
                        uniquePublicIPs.Add(rdpAuth[0], new HashSet<string>());
                    }
                    uniquePublicIPs[rdpAuth[0]].Add(rdpAuth[1]);
                    GenerateRdpFile(env.NetworkInterface.PrivateIpAddress, env.NetworkInterface.Username, rdpFolderPath, env.Name);
                    Console.WriteLine(env.NetworkInterface.RdpAuthority + " " + env.NetworkInterface.PrivateIpAddress);
                }

                using (StreamWriter writer = new StreamWriter(File.OpenWrite(Path.Combine(rdpFolderPath, "UniqueIPAddresses.txt"))))
                {
                    foreach (KeyValuePair<string, HashSet<string>> uniqueIp in uniquePublicIPs)
                    {
                        writer.WriteLine(uniqueIp.Key);
                        foreach (string port in uniqueIp.Value)
                        {
                            writer.WriteLine("\t" + port);
                        }
                    }
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
