# Az.LabServices

>### Azure Lab Services April 2022 update (preview)
>If you are using the update (with lab plans) the [Lab Services module](https://www.powershellgallery.com/packages/Az.LabServices/0.1.0) is available in the PowerShell gallery.  There is a dedicated [Lab Services repository](https://github.com/Azure/LabServices) with samples for the updated modules and the improved service.

Az.LabServices is a PowerShell module to simplify the management of [Azure Lab services](https://azure.microsoft.com/en-in/services/lab-services/). It provides composable functions to create, query, update and delete lab accounts, labs, VMs and Images.

Here is an example that showcases using the library to stop all the running VMs in all labs.

```powershell
Get-AzLabAccount | Get-AzLab | Get-AzLabVm -Status Running | Stop-AzLabVm
```

And [here](HowTo.md) is a step by step tutorial.

## Getting Started

1. Make sure you have a recent [Azure PowerShell Module](https://docs.microsoft.com/en-us/powershell/azure/overview) installed.
2. Copy Az.LabServices.psm1 anywhere on disk
3. Import the module

```powershell
Import-Module .\Az.LabServices.psm1
```

4. Start hacking !! (i.e. List all the labs in your subscription)

```powershell
Get-AzLabAccount | Get-AzLab
```

## Examples

More complex examples of usage are in the [Scenarios](./Scenarios) folder.

## Issues

Log issues on the [DevTest Labs Issues page](https://github.com/Azure/azure-devtestlab/issues). Please use the `Az.LabServices` label for the issue.

## Contributing

Please read [CONTRIBUTING.md](CONTRIBUTING.md) for details on how to contribute to the library.

## Open Source Code of Conduct

This project has adopted the [Microsoft Open Source Code of Conduct](https://opensource.microsoft.com/codeofconduct/). For more information see the [Code of Conduct FAQ](https://opensource.microsoft.com/codeofconduct/faq/) or contact [opencode@microsoft.com](mailto:opencode@microsoft.com) with any additional questions or comments.

## License

This project is licensed under the MIT License - see the [LICENSE.md](LICENSE.md) file for details
