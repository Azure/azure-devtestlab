using System;
using System.IO;
using System.Threading.Tasks;
using Microsoft.AspNetCore.Mvc;
using Microsoft.Azure.WebJobs;
using Microsoft.Azure.WebJobs.Extensions.Http;
using Microsoft.AspNetCore.Http;
using Microsoft.Extensions.Logging;
using Newtonsoft.Json;
using Microsoft.Azure.Management.DevTestLabs;
using Microsoft.Azure.Management.DevTestLabs.Models;
using System.Runtime.InteropServices;
using System.Collections.Generic;

namespace AzureFunctions
{
    public static class ApplyWindowsUpdateArtifact
    {
        [FunctionName("ApplyWindowsUpdateArtifact")]
        public static async Task<IActionResult> Run(
            [HttpTrigger(AuthorizationLevel.Function, "get", "post",
            Route = "subscriptions/{SUBSCRIPTIONID}/resourceGroups/{RESOURCEGROUPNAME}/providers/Microsoft.DevTestLab/labs/{LABNAME}/virtualmachines/{VIRTUALMACHINENAME}")] HttpRequest req,
            string subscriptionId,
            string resourceGroupName,
            string labName,
            string virtualMachineName,
            ILogger log)
        {
            log.LogInformation($"Function to apply the Windows Update artifact on VM {virtualMachineName} in lab {labName} in subscription {subscriptionId} started processing at {DateTime.Now}");

            // Authentication helper, keeps track of the access token and encapsulates authentication into Azure & DTL Client
            var authenticationHelper = new Authentication(log);
            await authenticationHelper.RetrieveAccessTokenAsync();

            // login to the DevTest Labs APIs
            var dtlClient = authenticationHelper.LoginToDevTestLabsAPIs(subscriptionId);
            var azureClient = authenticationHelper.LoginToAzure(subscriptionId);
            var devTestLabsHelper = new DevTestLabs(azureClient, dtlClient, log);

            // Get the lab's resource id (which also confirms the lab exists)
            string labResourceId = await devTestLabsHelper.GetDevTestLabResourceId(resourceGroupName, labName);

            // Get the virtual machine
            LabVirtualMachine vm = await devTestLabsHelper.GetDevTestLabVirtualMachine(resourceGroupName, labName, virtualMachineName);

            // Let's make sure the VM is OK to apply artifacts


            if (await devTestLabsHelper.IsVirtualMachineReadyForArtifacts(vm))
            {
                var artifactRequest = new ApplyArtifactsRequest(new List<ArtifactInstallProperties> {
                    new ArtifactInstallProperties($"{labResourceId}/artifactSources/public repo/artifacts/windows-install-windows-updates")
                });

                // We fire off the request to apply artifacts, but we don't wait until it's complete before wrapping up the function
                // If we wanted to wait, we would use "dtlClient.VirtualMachines.ApplyArtifactsAsync()" instead
                dtlClient.VirtualMachines.BeginApplyArtifacts(resourceGroupName, labName, virtualMachineName, artifactRequest);
            }
            else
            {
                log.LogError($"The VM must be running to apply artifacts!  ResourceGroupName '{resourceGroupName}', LabName '{labName}', VM '{virtualMachineName}'");

                return new ContentResult()
                {
                    Content = Content.GetHtmlResponse(Content.responseType.VirtualMachineNotRunning, false),
                    ContentType = "text/html",
                    StatusCode = 200
                };
            }

            return new ContentResult()
            {
                Content = Content.GetHtmlResponse(Content.responseType.VirtualMachineSuccess, true),
                ContentType = "text/html",
                StatusCode = 200
            };
        }
    }
}
