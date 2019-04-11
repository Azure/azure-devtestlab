using Microsoft.Azure.Management.DevTestLabs;
using Microsoft.Azure.Management.DevTestLabs.Models;
using System;
using System.Collections.Generic;
using System.Configuration;
using System.Threading.Tasks;

namespace DtlClient
{
    internal class Program
    {
        private static async Task ListLabsAsync()
        {
            var client = new DevTestLabsClient(new CustomLoginCredentials())
            {
                SubscriptionId = ConfigurationManager.AppSettings["SubscriptionId"]
            };

            foreach (var lab in await client.Labs.ListBySubscriptionAsync())
            {
                Console.WriteLine($"{lab.UniqueIdentifier}\t{lab.Name}");
            }
        }

        private static void AddAllowedPortsToSubnet(
            string subscriptionId,
            string labResourceGroupName,
            string labName,
            string labVirtualNetworkName,
            string location)
        {
            var virtualNetworkSubnetName = labVirtualNetworkName + "Subnet";

            var client = new DevTestLabsClient(new CustomLoginCredentials())
            {
                SubscriptionId = ConfigurationManager.AppSettings["SubscriptionId"]
            };
            Console.WriteLine("Fetching the lab...");
            var lab = client.Labs.Get(labResourceGroupName, labName);
            Console.WriteLine($"Lab ID: {lab.Id}");
            Console.WriteLine("Getting the lab's virtual network");
            var virtualNetwork = client.VirtualNetworks.Get(labResourceGroupName, labName, virtualNetworkSubnetName);
            Console.WriteLine("Virtual network ID: " + virtualNetwork.Id);
            Console.WriteLine("Enter Transport Protocol: TCP or UDP");
            string transportProtocol = Console.ReadLine();

            if (transportProtocol != null
                && transportProtocol.ToLowerInvariant() != "tcp"
                || transportProtocol.ToLowerInvariant() != "udp")

            {
                Console.WriteLine("Only TCP and UDP allowed exiting ... ");
                return;
            }

            string portRequest = Console.ReadLine();
            int.TryParse(portRequest, out int backendPort);

            if (transportProtocol != null && backendPort > 0)
            {
                var port = new Port(transportProtocol, backendPort);
                virtualNetwork.SubnetOverrides[0].SharedPublicIpAddressConfiguration.AllowedPorts.Add(port);
                return;
            }
        }

        private static void BulkCreateVirtualMachinesForLab(
            string subscriptionId,
            string labResourceGroupName,
            string labName,
            string labVirtualNetworkName,
            string location,
            int vmCount)
        {
            var virtualNetworkSubnetName = labVirtualNetworkName + "Subnet";

            var client = new DevTestLabsClient(new CustomLoginCredentials())
            {
                SubscriptionId = subscriptionId
            };

            Console.WriteLine("Fetching the lab...");
            var lab = client.Labs.Get(labResourceGroupName, labName);
            Console.WriteLine($"Lab ID: {lab.Id}");

            Console.WriteLine("Getting the lab's virtual network");
            var virtualNetwork = client.VirtualNetworks.Get(labResourceGroupName, labName, labVirtualNetworkName);
            Console.WriteLine("Virtual network ID: " + virtualNetwork.Id);

            Console.WriteLine($"Bulk-creating {vmCount} virtual machines...");
            client.Labs.CreateEnvironment(labName, new LabVirtualMachineCreationParameter
            {
                BulkCreationParameters = new BulkCreationParameters
                {
                    InstanceCount = vmCount
                },
                Location = location,
                AllowClaim = false,
                DisallowPublicIpAddress = true, /* Shared IP addresss */
                Name = "testvm1",
                Size = "Standard_DS1_V2",
                UserName = "testuserfoo",
                Password = "password123!@#",
                LabVirtualNetworkId = virtualNetwork.Id,
                LabSubnetName = virtualNetworkSubnetName,
                StorageType = StorageType.Premium,
                GalleryImageReference = new GalleryImageReference
                {
                    Offer = "BizTalk-Server",
                    OsType = "Windows",
                    Publisher = "MicrosoftBizTalkServer",
                    Sku = "2016-Standard",
                    Version = "latest"
                },
                NetworkInterface = new NetworkInterfaceProperties
                {
                    SharedPublicIpAddressConfiguration = new SharedPublicIpAddressConfiguration
                    {
                        InboundNatRules = new List<InboundNatRule>
                            {
                                new InboundNatRule
                                {
                                    TransportProtocol = "tcp",
                                    BackendPort = 3389,
                                }
                            }
                    }
                }
            });
        }

        private static void Main(string[] args)
        {
            try
            {
                // TODO: Enter your lab information.
                string labResourceGroupName = ConfigurationManager.AppSettings["LabResourceGroupName"];
                string labName = ConfigurationManager.AppSettings["LabName"];
                string virtualNetworkName = ConfigurationManager.AppSettings["VirtualMachineName"];
                string location = ConfigurationManager.AppSettings["LabLocation"];

                int vmCount = 10;

                if (args.Length == 0)
                {
                    Console.WriteLine("Missing required parameters.");
                    return;
                }

                switch (args[0])
                {
                    case "bulkcreate":
                        {
                            BulkCreateVirtualMachinesForLab(
                                ConfigurationManager.AppSettings["SubscriptionId"],
                                labResourceGroupName,
                                labName,
                                virtualNetworkName,
                                location,
                                vmCount);

                            Console.ForegroundColor = ConsoleColor.Green;
                            Console.WriteLine($"{vmCount} virtual machine(s) provisioned successfully.");
                            Console.ResetColor();

                            break;
                        }
                    case "labs":
                        {
                            ListLabsAsync().Wait();

                            Console.ForegroundColor = ConsoleColor.Green;
                            Console.WriteLine($"The operation completed successfully.");
                            Console.ResetColor();
                            break;
                        }
                    case "addAllowedPort":
                        {
                            AddAllowedPortsToSubnet(
                                 ConfigurationManager.AppSettings["SubscriptionId"],
                                 labResourceGroupName,
                                 labName,
                                 virtualNetworkName,
                                 location);
                            Console.WriteLine($"The operation completed successfully.");
                            break;
                        }

                }
            }
            catch (Exception ex)
            {
                Console.ForegroundColor = ConsoleColor.Red;
                Console.WriteLine(ex.ToString());
                Console.ResetColor();
            }
            finally
            {
                Console.WriteLine();
                Console.WriteLine("Press <ENTER> to continue.");
                Console.ReadLine();
            }
        }
    }
}
