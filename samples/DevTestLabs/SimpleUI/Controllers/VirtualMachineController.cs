using System;
using System.Collections.Generic;
using System.Net.Http.Headers;
using System.Threading.Tasks;
using Microsoft.AspNetCore.Mvc;
using Microsoft.Azure.Management.DevTestLabs;
using Microsoft.Azure.Management.DevTestLabs.Models;
using Microsoft.Extensions.Configuration;
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

        // Azure config settings
        private readonly string _labResourceGroupName;
        private readonly string _labName;
        private readonly string _subscriptionId;

        public VirtualMachineController(ILogger<VirtualMachineController> logger, IConfiguration config)
        {
            _logger = logger ?? throw new ArgumentNullException(nameof(logger));

            // Assign config settings
            _labResourceGroupName = config.GetValue<string>("LabResourceGroupName");
            _labName = config.GetValue<string>("LabName");
            _subscriptionId = config.GetValue<string>("SubscriptionId");
        }

        [HttpGet]
        [Route("/virtualmachines")]
        public async Task<IEnumerable<LabVirtualMachine>> ListVirtualMachines()
        {
            IDevTestLabsClient labClient = GetDevTestLabsClient();

            try
            {
                _logger.LogInformation($"Retrieving VMs from resource group {_labResourceGroupName}, lab {_labName}");

                IPage<LabVirtualMachine> virtualMachines = await labClient.VirtualMachines.ListAsync(_labResourceGroupName, _labName);
                
                return virtualMachines;
            }
            catch (CloudException ex)
            {
                _logger.LogError(ex, $"Error retrieving VMs for resource group {_labResourceGroupName}, lab {_labName}");

                throw;
            }
        }

        [HttpPost]
        [Route("/virtualmachines/unclaim/{vmName}")]
        public async Task UnclaimVirtualMachine(string vmName)
        {
            IDevTestLabsClient labClient = GetDevTestLabsClient();

            try
            {
                _logger.LogInformation($"Un-claiming VM {vmName}");

                await labClient.VirtualMachines.UnClaimAsync(_labResourceGroupName, _labName, vmName);
            }
            catch (CloudException ex)
            {
                _logger.LogError(ex, $"Error un-claiming VM {vmName}");

                throw;
            }
        }

        [HttpPost]
        [Route("/virtualmachines/claim/{vmName}")]
        public async Task ClaimVirtualMachine(string vmName)
        {
            IDevTestLabsClient labClient = GetDevTestLabsClient();

            try
            {
                _logger.LogInformation($"Claiming VM {vmName}");

                await labClient.VirtualMachines.ClaimAsync(_labResourceGroupName, _labName, vmName);
            }
            catch (CloudException ex)
            {
                _logger.LogError(ex, $"Error claiming VM {vmName}");

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
                SubscriptionId = _subscriptionId
            };
        }
    }
}
