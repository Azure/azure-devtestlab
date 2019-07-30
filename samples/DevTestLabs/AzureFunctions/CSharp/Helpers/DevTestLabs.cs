using Microsoft.Azure.Management.DevTestLabs;
using Microsoft.Azure.Management.DevTestLabs.Models;
using Microsoft.Azure.Management.Fluent;
using Microsoft.Extensions.Logging;
using System;
using System.Collections.Generic;
using System.Linq;
using System.Security.Cryptography;
using System.Text;
using System.Threading.Tasks;

namespace AzureFunctions
{
    public class DevTestLabs
    {
        private ILogger log { get; set; }
        private DevTestLabsClient dtlClient { get; set; }
        private IAzure azureClient { get; set; }

        public DevTestLabs(IAzure azure, DevTestLabsClient dtl, ILogger functionsLog)
        {
            // Keep a handle to the paramenters so we can use them later
            azureClient = azure;
            dtlClient = dtl;
            log = functionsLog;
        }

        public async Task<string> GetDevTestLabResourceId(string resourceGroupName, string labName)
        {
            var resourceId = string.Empty;
            try
            {
                // this call throws an exception if we can't find the lab.  The most likely case 
                // is that the request contained invalid information (invalid lab name for example)
                var lab = await dtlClient.Labs.GetAsync(resourceGroupName, labName);
                return lab.Id;
            }
            catch (Exception e)
            {
                // Couldn't find the lab
                log.LogError($"Perhaps the ResourceGroupName '{resourceGroupName}' or LabName '{labName}' doesn't exist or user doesn't have access? Operation failed with error: {e.Message}");
                throw;
            }
        }

        public async Task<LabVirtualMachine> GetDevTestLabVirtualMachine(string resourceGroupName, string labName, string virtualMachineName)
        {
            try
            {
                // this call throws an exception if we can't find the VM.  Most likely case
                // is that the request contained invalid info (invalid lab name, or invalid VM name)
                var vm = await dtlClient.VirtualMachines.GetAsync(resourceGroupName, labName, virtualMachineName, "Properties($expand=ComputeVm)");
                return vm;
            }
            catch (Exception e)
            {
                // Couldn't find the VM
                log.LogError($"Perhaps the ResourceGroupName '{resourceGroupName}' or LabName '{labName}' or VM '{virtualMachineName}' doesn't exist or the user doesn't have access?  Operation failed with error: {e.Message}");
                throw;
            }
        }

        public async Task<bool> IsVirtualMachineReadyForArtifacts(LabVirtualMachine vm)
        {
            // 1st, we have to first check the lab machine provisioning state (this ensures that the VM isn't creating, deleting, applying artifacts, etc)
            if (vm.ProvisioningState == "Succeeded")
            {
                // 2nd, we need to ensure that the underlying compute has provisioning state == succeeded and power state == running
                string powerState, provisioningState;

                if (vm.ComputeVm != null)
                {
                    // If we already have the Compute VM, let's use it directly rather than query Azure again
                    powerState = (from s in vm.ComputeVm.Statuses
                                     where s.Code.Contains("PowerState/")
                                     select s).FirstOrDefault()?.Code.Replace("PowerState/", "").ToLower();
                    provisioningState = (from s in vm.ComputeVm.Statuses
                                             where s.Code.Contains("ProvisioningState/")
                                             select s).FirstOrDefault()?.Code.Replace("ProvisioningState/", "").ToLower();
                }
                else
                {
                    // We don't have the compute VM, so we need the underlying resource status to continue
                    var computeVm = await azureClient.VirtualMachines.GetByIdAsync(vm.ComputeId);

                    powerState = computeVm.PowerState?.Value.Replace("PowerState/", "").ToLower();
                    provisioningState = computeVm.ProvisioningState.Replace("ProvisioningState/", "").ToLower();
                }

                if (powerState == "running" &&  provisioningState == "succeeded")
                {
                    return true;
                }
                else
                {
                    log.LogInformation($"  .. Virtual machine '{vm.Name}' has PowerState '{powerState}' and ProvisioningState '{provisioningState}', cannot apply artifacts ");
                    return false;
                }


            }
            else
            {
                log.LogInformation($"  .. Virtual machine '{vm.Name}' has DTL ProvisioningState '{vm.ProvisioningState}', cannot apply artifacts ");
                return false;
            }
        }
    }
}
