using System;
using System.Collections.Generic;
using System.Net.Http.Headers;
using System.Threading.Tasks;
using Microsoft.AspNetCore.Mvc;
using Microsoft.Azure.Management.DevTestLabs;
using Microsoft.Azure.Management.DevTestLabs.Models;
using Microsoft.Extensions.Logging;
using Microsoft.Net.Http.Headers;
using Microsoft.Rest;
using Microsoft.Rest.Azure;

namespace SimpleDtlUI.Controllers
{
    [ApiController]
    [Route("[controller]")]
    public class VirtualMachineController : ControllerBase
    {
        private readonly ILogger<VirtualMachineController> _logger;

        // Put into app settings file, note in README that these properties should be updated by the user
        private const string LabResourceGroupName = "sodasing-lab-rg";
        private const string LabName = "sodasing-lab";
        private const string SubscriptionId = "0c0ff9e3-52f3-4756-8551-2271c1cc9121";
        private const string VirtualNetworkName = "Dtlsodasing-lab";

        public VirtualMachineController(ILogger<VirtualMachineController> logger)
        {
            _logger = logger;
        }

        [HttpGet]
        [Route("/virtualmachines")]
        public async Task<IEnumerable<LabVirtualMachine>> Get()
        {
            IDevTestLabsClient labClient = GetDevTestLabsClient();

            try
            {
                _logger.LogInformation($"Retrieving virtual machines from resource group {LabResourceGroupName}, lab {LabName}");

                IPage<LabVirtualMachine> virtualMachines = await labClient.VirtualMachines.ListAsync(LabResourceGroupName, LabName);

                return virtualMachines;
            }
            catch (CloudException ex)
            {
                _logger.LogError(ex, $"Error calling ListAsync API for resource group {LabResourceGroupName}, lab {LabName}");

                throw;
            }
        }

        [HttpPost]
        [Route("/virtualmachines")]
        public async Task Post(string vmName)
        {
            IDevTestLabsClient labClient = GetDevTestLabsClient();

            try
            {
                _logger.LogInformation($"Creating virtual machine in {LabResourceGroupName}, lab {LabName}");

                // TODO: Should VM info be in config?
                LabVirtualMachine labVM = new LabVirtualMachine
                {
                    UserName = "vmadmin",
                    Password = Guid.NewGuid().ToString(),
                    OsType = "Linux",
                    Size = "Standard_A2_v2",
                    LabVirtualNetworkId = $"/subscriptions/{SubscriptionId}/resourcegroups/{LabResourceGroupName}/providers/microsoft.devtestlab/labs/{LabName}/virtualnetworks/{VirtualNetworkName}",
                    LabSubnetName = $"{VirtualNetworkName}Subnet",
                    GalleryImageReference = new GalleryImageReference
                    {
                        OsType = "Linux",
                        Version = "Latest",
                        Sku = "16.04-LTS",
                        Offer = "UbuntuServer",
                        Publisher = "Canonical"
                    },
                    Location = "West US 2"
                };

                await labClient.VirtualMachines.BeginCreateOrUpdateAsync(LabResourceGroupName, LabName, Guid.NewGuid().ToString(), labVM);
            }
            catch (CloudException ex)
            {
                _logger.LogError(ex, $"Error calling BeginCreateOrUpdateAsync API for resource group {LabResourceGroupName}, lab {LabName}");

                throw;
            }
        }

        private TokenCredentials GetCredentialsFromHeader()
        {
            AuthenticationHeaderValue auth = AuthenticationHeaderValue.Parse(Request.Headers[HeaderNames.Authorization]);

            return new TokenCredentials(auth.Parameter);
        }

        private IDevTestLabsClient GetDevTestLabsClient()
        {
            TokenCredentials credentials = GetCredentialsFromHeader();

            return new DevTestLabsClient(credentials)
            {
                SubscriptionId = SubscriptionId
            };
        }
    }
}
