using Microsoft.Azure.Management.DevTestLabs;
using Microsoft.Azure.Management.LabServices;
using System;
using System.Collections.Generic;
using System.Configuration;
using System.IO;
using System.Linq;
using System.Threading.Tasks;
using LSEnvironment = Microsoft.Azure.Management.LabServices.Models.Environment;
using LSEnvironmentSetting = Microsoft.Azure.Management.LabServices.Models.EnvironmentSetting;

namespace SDKSample
{
    internal static class PeeredVnetScenario
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
            using (IManagedLabsClient client = Utilities.CreateManagedLabsClient())
            {
                // Get all VMs within the lab
                List<(LSEnvironmentSetting, LSEnvironment)> envSettingEnvPairs = new List<(LSEnvironmentSetting, LSEnvironment)>();
                foreach (LSEnvironmentSetting envSetting in (await client.EnvironmentSettings.ListAsync(resourceGroupName, labAccountName, labName)))
                {
                    foreach (LSEnvironment tempenvironment in await client.Environments.ListAsync(resourceGroupName, labAccountName, labName, envSetting.Name))
                    {
                        envSettingEnvPairs.Add((envSetting, tempenvironment));
                    }
                }

                // For each Environment, do an expand on the network interface to get RDP info
                LSEnvironment[] expandedEnvironments = await Task.WhenAll(
                    envSettingEnvPairs.Select(envtuple =>
                    client.Environments.GetAsync(resourceGroupName, labAccountName, labName, envtuple.Item1.Name, envtuple.Item2.Name, "properties($expand=networkInterface)")));

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
                    Utilities.GenerateRdpFile(env.NetworkInterface.PrivateIpAddress, env.NetworkInterface.Username, rdpFolderPath, env.Name);
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
    }
}
