# Az.DevTestLabs   [![Build status](https://dotnetcst.visualstudio.com/DTL-Library/_apis/build/status/Validate%20the%20DTl%20Library)](https://dotnetcst.visualstudio.com/DTL-Library/_build/latest?definitionId=63)

Az.DevTestLabs is a PowerShell module to simplify the management of [Azure DevTest Labs](https://azure.microsoft.com/en-us/services/devtest-lab/). It provides composable functions to create, query, update and delete labs, VMs, Custom Images and Environments.

Here is an example that showcases using the library to start all the VMs in all the labs whose name start with the prefix "Test".

```powershell
Get-AzDtlLab -name Test* | Get-AzDtlVm | Start-AzDtlVm
```

And [here](HowTo.md) is a step by step tutorial.

## Getting Started

1. Make sure you have a recent [Azure PowerShell Module](https://docs.microsoft.com/en-us/powershell/azure/overview) installed.
2. Copy Az.DevTestLabs2.psm1 anywhere on disk
3. Import the module

```powershell
Import-Module .\Az.DevTestLabs2.psm1
```

4. Start hacking !! (i.e. List all the labs in your subscription)

```powershell
Get-AzDtlLab
```

## Examples

More complex examples of usage are in the [Scenarios](./Scenarios) folder.

## Issues

Log issues on the [DevTest Labs Issues page](https://github.com/Azure/azure-devtestlab/issues). Please put [AZ.DEVTESTLABS] in the title for easy scanning.

## Contributing

Please read [CONTRIBUTING.md](CONTRIBUTING.md) for details on how to contribute to the library.

## Authors

* **[Luca Bolognese](https://github.com/lucabol)** - *Initial work*
* **[Peter Hauge](https://github.com/petehauge)**
* **[Roger Best](https://github.com/rogerbestmsft)**

## Open Source Code of Conduct

This project has adopted the [Microsoft Open Source Code of Conduct](https://opensource.microsoft.com/codeofconduct/). For more information see the [Code of Conduct FAQ](https://opensource.microsoft.com/codeofconduct/faq/) or contact [opencode@microsoft.com](mailto:opencode@microsoft.com) with any additional questions or comments.

## License

This project is licensed under the MIT License - see the [LICENSE.md](LICENSE.md) file for details

## Acknowledgments

* **[Leo Vildosola](https://github.com/leovms)** - *for reviewing the initial work*
