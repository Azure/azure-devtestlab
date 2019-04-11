using Microsoft.IdentityModel.Clients.ActiveDirectory;
using Microsoft.Rest;
using System;
using System.Configuration;
using System.Globalization;
using System.Net.Http;
using System.Net.Http.Headers;
using System.Threading;
using System.Threading.Tasks;

namespace DtlClient
{
    public class CustomLoginCredentials : ServiceClientCredentials
    {
        private string AuthenticationToken { get; set; }
        public override void InitializeServiceClient<T>(ServiceClient<T> client)
        {
            var authorityUri = string.Format(
                CultureInfo.InvariantCulture,
                ConfigurationManager.AppSettings["Authority"],
                ConfigurationManager.AppSettings["TenantId"]);

            var authContext = new AuthenticationContext(authorityUri, new TokenCache());

            var resourceUri = ConfigurationManager.AppSettings["ArmResourceId"];
            var clientId = ConfigurationManager.AppSettings["ida:ClientId"];
            var redirectUri = ConfigurationManager.AppSettings["RedirectUri"];

            Task<AuthenticationResult> task = authContext.AcquireTokenAsync(resourceUri, clientId, new Uri(redirectUri), new PlatformParameters(PromptBehavior.Auto));
            task.Wait();

            AuthenticationResult token = task.Result;

            if (token == null)
            {
                throw new InvalidOperationException("Failed to obtain the JWT token");
            }

            AuthenticationToken = token.AccessToken;
        }

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
