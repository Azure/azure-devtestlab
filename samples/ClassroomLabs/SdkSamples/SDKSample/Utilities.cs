using Microsoft.Azure.Management.LabServices;
using Microsoft.Azure.Management.ResourceManager.Fluent;
using Microsoft.Rest;
using System.Configuration;
using System.IO;

namespace SDKSample
{
    /// <summary>
    /// Some utility methods to set up the sample workflows.
    /// </summary>
    public class Utilities
    {
        /// <summary>
        /// Creates a properly formatted RDP file.
        /// </summary>
        /// <param name="rdpAuthority">The address of the machine.</param>
        /// <param name="userName">The username to use at login.</param>
        /// <param name="rdpFolderPath">The folder to save the RDP file to.</param>
        /// <param name="rdpFileName">The name to use for the RDP file.</param>
        public static void GenerateRdpFile(string rdpAuthority, string userName, string rdpFolderPath, string rdpFileName)
        {
            string fileContent = $"full address:s:{rdpAuthority}" +
              "\nprompt for credentials:i:1" +
              $"\nusername:s:~\\{userName}";
            string fileName = Path.Combine(rdpFolderPath, rdpFileName + ".rdp");
            File.WriteAllText(fileName, fileContent);
        }

        /// <summary>
        /// Creates the credentials to use in the Azure client.
        /// </summary>
        /// <returns>Credentials for an Azure Service Principal based on values in the app.config.</returns>
        public static ServiceClientCredentials CreateCredentials()
        {
            return SdkContext.AzureCredentialsFactory
                .FromFile(ConfigurationManager.AppSettings["AuthFile"]);
        }

        /// <summary>
        /// Creates an instance of the ManagedLabsClient to use to call your instance of Lab Services.
        /// </summary>
        /// <returns>A fully instantiated ManagedLabsClient based on values in the app.config.</returns>
        public static IManagedLabsClient CreateManagedLabsClient()
        {
            return new ManagedLabsClient(CreateCredentials())
            {
                SubscriptionId = ConfigurationManager.AppSettings["SubscriptionId"],
            };
        }
    }
}
