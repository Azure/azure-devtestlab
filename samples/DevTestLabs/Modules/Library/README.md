# Az.DevTestLabs

Az.DevTestLabs is a Powershell module to simplify the management of [Azure DevTest Labs](https://azure.microsoft.com/en-us/services/devtest-lab/).

It provides composable functions to create, query, update and delete labs, VMs, Environments, etc...

It looks like this ...

```powershell
Dtl-GetLab -name Test* | Dtl-GetVm | Dtl-StartVm
```

## Getting Started

1. Make sure you have a recent [Azure Powershell Module](https://docs.microsoft.com/en-us/powershell/azure/install-az-ps?view=azps-2.1.0) installed.
2. Copy Az.DevTestLabs.psm1 anywhere on disk
3. Import the module
```powershell
Import-Module .\AzureRM.DevTestLab.psm1

```
4. Start hacking !! (i.e. List all the labs in your subscription)
```powershell
Dtl-GetLab
```

## Examples

More complex examples of usage are in the [Scenarios](./Scenarios) folder.

## Contributing

Please read [CONTRIBUTING.md](./CONTRIBUTING.MD) for details on our code of conduct, and hints on how to code for this repo.

## Versioning

We use [SemVer](http://semver.org/) for versioning. For the versions available, see the [tags on this repository](https://github.com/your/project/tags). 

## Authors

* **[Luca Bolognese](https://github.com/lucabol)** - *Initial work*
* **[Peter Hauge](https://github.com/petehauge)**
* **[Roger Best](https://github.com/rogbest)**

## License

This project is licensed under the MIT License - see the [LICENSE.md](LICENSE.md) file for details

## Acknowledgments

* **[Leo Vildosola](https://github.com/leovms)** - *for reviewing the initial work*
