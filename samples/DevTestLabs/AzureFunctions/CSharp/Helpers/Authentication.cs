using Microsoft.Azure.Management.DevTestLabs;
using Microsoft.Azure.Management.Fluent;
using Microsoft.Azure.Management.ResourceManager.Fluent;
using Microsoft.Azure.Management.ResourceManager.Fluent.Authentication;
using Microsoft.Azure.Management.ResourceManager.Fluent.Core;
using Microsoft.Extensions.Configuration;
using Microsoft.Extensions.Logging;
using Microsoft.IdentityModel.Clients.ActiveDirectory;
using Microsoft.Rest;
using Newtonsoft.Json;
using Newtonsoft.Json.Linq;
using System;
using System.Collections.Generic;
using System.Dynamic;
using System.Net.Http;
using System.Net.Http.Headers;
using System.Text;
using System.Threading;
using System.Threading.Tasks;

namespace AzureFunctions
{
    internal class Authentication
    {
        // this is the .net core way to build configuration, includes both local debugging (local.settings.jon) 
        // and running in Azure (Envrionment Variables set by app configuration)
        // More information found here:  https://docs.microsoft.com/en-us/aspnet/core/fundamentals/configuration/?view=aspnetcore-2.2
        private static IConfigurationRoot config = new ConfigurationBuilder()
            .SetBasePath(Environment.CurrentDirectory)
            .AddJsonFile("local.settings.json", optional: true, reloadOnChange: true)
            .AddEnvironmentVariables()
            .Build();

        private string appId { get; set; }
        private string clientSecret { get; set; }
        private string tenant { get; set; }
        private string accessToken { get; set; }

        private ILogger log { get; set; }

        public Authentication(ILogger functionsLog)
        {
            this.log = functionsLog;

            // Initialize our helper library for querying Application Settings
            var settings = new Settings(functionsLog);

            // Get the application settings for service princpal
            appId = settings.GetSetting<string>("ServicePrincipal_AppId");
            clientSecret = settings.GetSetting<string>("ServicePrincipal_Key");
            tenant = settings.GetSetting<string>("ServicePrincipal_Tenant");

            // Confirm that we were able to get the settings
            if (appId == null || clientSecret == null || tenant == null)
            {
                throw new ArgumentException("Unable to retrieve necessary application settings to proceed..");
            }
        }

        public async Task<Authentication> RetrieveAccessTokenAsync()
        {
            log.LogInformation($"   Retrieving AccessToken from Azure...");

            // we are getting an access token (essentially manually authenticating) intentionally in the case where we login
            // for both the DTL Client and for Azure.  If we get an access token, we only need to do this OAuth2 flow once, get
            // the token and use it in both places.  If we dont do it this way, we end up running these steps twice

            var clientCredential = new ClientCredential(appId, clientSecret);
            var context = new AuthenticationContext("https://login.microsoftonline.com/" + tenant);
            var AuthResult = await context.AcquireTokenAsync("https://management.core.windows.net/", clientCredential);

            if (AuthResult == null || AuthResult.AccessToken == null)
            {
                log.LogError($"Unable to login to Azure and retrieve AccessToken - Service Principal info must be incorrect (expired secret?)");
            }
            else
            {
                // save the access token for using the Azure or DTL APIs
                accessToken = AuthResult.AccessToken;
            }

            return this;
        }

        public IAzure LoginToAzure(string subscriptionId)
        {
            // We are logging into Azure with a token instead of with the service principal directly
            // This saves us a round trip logging in again with the DTL client
            var tokenCredentials = new TokenCredentials(accessToken);

            var customTokenProvider = new AzureCredentials(
                        new TokenCredentials(accessToken),
                        new TokenCredentials(accessToken),
                        tenant,
                        AzureEnvironment.AzureGlobalCloud);

            var client = RestClient
                            .Configure()
                            .WithEnvironment(AzureEnvironment.AzureGlobalCloud)
                            .WithLogLevel(HttpLoggingDelegatingHandler.Level.Basic)
                            .WithCredentials(customTokenProvider)
                            .Build();

            var azure = Azure.Authenticate(client, tenant)
                .WithSubscription(subscriptionId);

            return azure;
        }

        public DevTestLabsClient LoginToDevTestLabsAPIs(string subscriptionId)
        {
            // We are logging into Azure with a token, this is the standard way of logging in for the DTL client
            // Example here:  https://github.com/Azure/azure-devtestlab/blob/master/SdkSamples/DtlClient/Program.cs
            var Dtlclient = new DevTestLabsClient(new CustomDtlLoginCredentials() { AuthenticationToken = accessToken })
            {
                SubscriptionId = subscriptionId
            };

            return Dtlclient;
        }
    }

    // This is a standard implementation for handling token headers, copied from here:
    // https://github.com/Azure/azure-devtestlab/blob/master/SdkSamples/DtlClient/CustomLoginCredentials.cs
    public class CustomDtlLoginCredentials : ServiceClientCredentials
    {
        public string AuthenticationToken { get; set; }

        public override async Task ProcessHttpRequestAsync(HttpRequestMessage request, CancellationToken cancellationToken)
        {
            if (request == null)
            {
                throw new ArgumentNullException(nameof(request));
            }

            if (AuthenticationToken == null)
            {
                throw new InvalidOperationException("Token Provider cannot be null");
            }

            request.Headers.Authorization = new AuthenticationHeaderValue("Bearer", AuthenticationToken);
            request.Headers.Accept.Add(new MediaTypeWithQualityHeaderValue("application/json"));

            await base.ProcessHttpRequestAsync(request, cancellationToken);
        }
    }
}
