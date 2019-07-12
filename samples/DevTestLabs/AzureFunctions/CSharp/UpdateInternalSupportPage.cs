using System;
using System.IO;
using System.Threading.Tasks;
using Microsoft.AspNetCore.Mvc;
using Microsoft.Azure.WebJobs;
using Microsoft.Azure.WebJobs.Extensions.Http;
using Microsoft.AspNetCore.Http;
using Microsoft.Extensions.Logging;
using System.Linq;
using Newtonsoft.Json;
using Microsoft.Azure.Management.DevTestLabs;
using Microsoft.Azure.Management.DevTestLabs.Models;
using System.Text;
using System.Net.NetworkInformation;
using System.Net.Http;
using System.Net.Http.Headers;
using System.Net.Mime;

namespace AzureFunctions
{
    public static class UpdateInternalSupportPage
    {

        [FunctionName("UpdateInternalSupportPage")]
        public static async Task<IActionResult> Run(
            [HttpTrigger(AuthorizationLevel.Function, "get", "post",
            Route = "subscriptions/{SUBSCRIPTIONID}/resourceGroups/{RESOURCEGROUPNAME}/providers/Microsoft.DevTestLab/labs/{LABNAME}")] HttpRequest req,
            string subscriptionId,
            string resourceGroupName,
            string labName,
            ILogger log)
        {
            log.LogInformation($"Function to update the InternalSupport page in lab {labName} in subscription {subscriptionId} started processing at {DateTime.Now}");

            // Authentication helper, keeps track of the access token and encapsulates authentication into Azure & DTL Client
            var authenticationHelper = new Authentication(log);
            await authenticationHelper.RetrieveAccessTokenAsync();

            // Content helper, helps build up the templates, content & strings
            var content = new Content(log)
            {
                SubscriptionId = subscriptionId,
                ResourceGroupName = resourceGroupName,
                DevTestLabName = labName
            };

            // login to the DevTest Labs APIs
            var dtlClient = authenticationHelper.LoginToDevTestLabsAPIs(subscriptionId);
            var azureClient = authenticationHelper.LoginToAzure(subscriptionId);
            var dtlHelper = new DevTestLabs(azureClient, dtlClient, log);

            // this call throws an exception if we can't find the lab.  The most likely case 
            // is that the request contained invalid information (invalid lab name for example)
            // we use that for validation that the lab really exists
            await dtlHelper.GetDevTestLabResourceId(resourceGroupName, labName);

            // Get the list of virtual machines in a lab including any artifacts that were applied
            var virtualMachines = await dtlClient.VirtualMachines.ListAsync(resourceGroupName, labName, "''&$expand=Properties($expand=Artifacts)");

            // Add in the list of VMs to the page content
            content.AddVirtualMachines(virtualMachines);

            string finalMarkDown = content.GetMarkdown();

            // get the lab again - just to ensure we have the latest before updating (so we don't accidently update with old properties)
            // Information we need for the Virtual Machines: Name, OS, Claimable, Owner, applied artifacts, Needs Windows Updates
            log.LogInformation("  Updating the lab with the new internal support page");
            var lab = await dtlClient.Labs.GetAsync(resourceGroupName, labName);
            lab.Support = new LabSupportProperties("enabled", finalMarkDown);

            // Choose a really short polling duration because updating the lab's properties is fast
            // ONLY do this for lab property updates, do not set this timeout so low for 'Create' operations
            dtlClient.LongRunningOperationRetryTimeout = 0;
            await dtlClient.Labs.CreateOrUpdateAsync(resourceGroupName, labName, lab);
            // Set the polling duration for the client back to 30 (the default)
            dtlClient.LongRunningOperationRetryTimeout = 30;

            log.LogInformation($"Function to update the InternalSupport page in lab {labName} in subscription {subscriptionId} completed processing at {DateTime.Now}");

            return new ContentResult()
            {
                Content = Content.GetHtmlResponse(Content.responseType.LabSuccess, true),
                ContentType = "text/html",
                StatusCode = 200
            };
        }
    }
}
