# Bulk Lab Creation Module <!-- omit in toc -->
The [Az.LabServices.BulkOperations.psm1](https://github.com/Azure/azure-devtestlab/blob/master/samples/ClassroomLabs/Modules/Library/BulkOperations/Az.LabServices.BulkOperations.psm1) module enables bulk operations on **Resource Groups**, **Lab Accounts** and **Labs** via commandline based on declarative configuration information. The standard pattern of usage is by composing a pipeline as follows:

`Load configuration info from db/csv/...` => `Transform configuration info` => `Publish the labs`

## Table of Contents
- [Table of Contents](#table-of-contents)
- [Getting Started](#getting-started)
- [Examples](#examples)
  - [Publish all the labs in a CSV file (Examples/PublishAll.ps1)](#publish-all-the-labs-in-a-csv-file-examplespublishallps1)
  - [Publish all the labs in a JSON file (Examples/PublishAllJson.ps1)](#publish-all-the-labs-in-a-json-file-examplespublishalljsonps1)
  - [Publish all the labs with a particular tag (Examples/PublishByTag.ps1)](#publish-all-the-labs-with-a-particular-tag-examplespublishbytagps1)
  - [Publish one lab with a given id (Examples/PublishById.ps1)](#publish-one-lab-with-a-given-id-examplespublishbyidps1)
  - [Publish one lab changing some configuration properties (i.e. a staging ResourceGroup)(Examples/PublishStaging.ps1)](#publish-one-lab-changing-some-configuration-properties-ie-a-staging-resourcegroupexamplespublishstagingps1)
  - [Show a menu asking to select one lab (Examples/PickALab.ps1)](#show-a-menu-asking-to-select-one-lab-examplespickalabps1)
  - [Show a menu to the user asking for the value of some properties (Examples/PickProperties.ps1)](#show-a-menu-to-the-user-asking-for-the-value-of-some-properties-examplespickpropertiesps1)
  - [Show a menu to the user asking to select a lab and the value of some properties(Examples/PickLabAndProperties.ps1)](#show-a-menu-to-the-user-asking-to-select-a-lab-and-the-value-of-some-propertiesexamplespicklabandpropertiesps1)
- [Structure of the example Hogwarts.csv](#structure-of-the-example-hogwartscsv)
- [Structure of the example Charms.csv](#structure-of-the-example-charmscsv)

## Getting Started
The [Bulk Lab Creation functions](https://github.com/Azure/azure-devtestlab/tree/master/samples/ClassroomLabs/Modules/Library/Tools) can be run from an authenticated Azure PowerShell session and requires [PowerShell](https://github.com/PowerShell/PowerShell/releases) and the [Azure PowerShell](https://docs.microsoft.com/en-us/powershell/azure/) module.  The script will automatically install the [ThreadJob](https://docs.microsoft.com/en-us/powershell/module/threadjob)  Powershell Module.

To get started, using the example configuration csv files:

1. Get a local copy of the LabCreator.ps1 script by either [cloning the repo](https://github.com/Azure/azure-devtestlab.git) or by [downloading a copy](https://raw.githubusercontent.com/Azure/azure-devtestlab/master/samples/ClassroomLabs/Modules/Library/BulkOperations/Az.LabServices.BulkOperations.psm1)
1. Get a local copy of the example [hogwarts.csv](https://raw.githubusercontent.com/Azure/azure-devtestlab/master/samples/ClassroomLabs/Modules/Library/Tools/hogwarts.csv) file and example [charms.csv](https://raw.githubusercontent.com/Azure/azure-devtestlab/master/samples/ClassroomLabs/Modules/Library/Tools/charms.csv) file
1. Launch a PowerShell session
1. Ensure [Azure PowerShell](https://docs.microsoft.com/en-us/powershell/azure/install-az-ps) installed
1. Update the example CSV files to configure the resources to be created.  For additional labs, create additional lines in the CSV file.  The CSV files can be modified directly with Microsoft Excel.
1. Import the functions in the script by typing:
```powershell
Import-Module .\Az.LabServices.BulkOperations.psm1
```

## Examples
The functions are generic and can be composed together to achieve different aims. In the following examples, we load the configuration information from a CSV file. The examples work the same if the information is loaded from a database. You need to substitute the first function with a database retrieving one.

The examples scripts expect the modules used to be in the following directories:

```powershell
Import-Module ../../Az.LabServices.psm1 -Force
Import-Module ../Az.LabServices.BulkOperations.psm1 -Force
```

The full code for the example is immediately after the title in parenthesis.

### Publish all the labs in a CSV file ([Examples/PublishAll.ps1](./Examples/PublishAll.ps1))

```powershell
".\hogwarts.csv" | Import-LabsCsv | Publish-Labs
```
* `Import-LabsCsv` loads the configuration information from the csv file. It also loads schedule information for each lab from a separate file.
* `Publish-Labs` publishes the labs and it is the natural end to all our pipelines. You can specify how many concurrent threads to use with the parameter `ThrottleLimit`.

### Publish all the labs in a JSON file ([Examples/PublishAllJson.ps1](./Examples/PublishAllJson.ps1))
You can store your configuration information in JSON form as well (i.e., file, Azure CosmoDb, other).

```powershell
Get-Content -Raw -Path "hogwarts.json" | ConvertFrom-Json | Publish-Labs
```

### Publish all the labs with a particular tag ([Examples/PublishByTag.ps1](./Examples/PublishByTag.ps1))

```powershell
".\hogwarts.csv"  | Import-LabsCsv | Select-Lab -SomeTags Maths, Science | Publish-Labs
```

In the example csv configuration file, the `Tags` column contains the emails of the professors that are giving a certain course. You can create the labs for a particular professor with:

```powershell
".\hogwarts.csv"  | Import-LabsCsv | Select-Lab -SomeTags bool1@hotmail.com | Publish-Labs
```

* `Select-Lab` is just a convenience function. You can achieve the same result by using any of the `Powershell` provided selection functions (i.e., `Where-Object`).
 
### Publish one lab with a given id ([Examples/PublishById.ps1](./Examples/PublishById.ps1))

```powershell
".\hogwarts.csv"  | Import-LabsCsv | Select-Lab -AnId id001 | Publish-Labs
```

### Publish one lab changing some configuration properties (i.e. a staging ResourceGroup)([Examples/PublishStaging.ps1](./Examples/PublishStaging.ps1))

```powershell
".\hogwarts.csv" `
  | Import-LabsCsv `
  | Select-Lab -Id id001 `
  | Set-LabProperty -ResourceGroupName Staging -MaxUsers 50 `
  | Publish-Labs
```

* You can use any of the `Select-*` functions to choose labs. All the chosen labs will be modified by the `Set-LabProperty` function.

### Show a menu asking to select one lab ([Examples/PickALab.ps1](./Examples/PickALab.ps1))

```console
".\hogwarts.csv" | Import-LabsCsv | Show-LabMenu -PickLab | Publish-Labs

LABS
[0]     id001   hogwarts-rg2    History of Magic
[1]     id002   hogwarts-rg2    Transfiguration
[2]     id003   hogwarts-rg2    Charms
Please select the lab to create:
```

* The fields displayed for the various labs are fixed. Log an issue if you want me to make them configurable.

### Show a menu to the user asking for the value of some properties ([Examples/PickProperties.ps1](./Examples/PickProperties.ps1))

```console
".\hogwarts.csv" `
  | Import-LabsCsv `
  | Show-LabMenu -Properties LabName,MaxUsers `
  | Publish-Labs

LabName: TestLab
MaxUsers: 10
```

### Show a menu to the user asking to select a lab and the value of some properties([Examples/PickLabAndProperties.ps1](./Examples/PickLabAndProperties.ps1))

```console
".\hogwarts.csv" `
  | Import-LabsCsv `
  | Show-LabMenu -PickLab -Properties LabName,MaxUsers `
  | Publish-Labs

LABS
[0]     id001   hogwarts-rg2    History of Magic
[1]     id002   hogwarts-rg2    Transfiguration
[2]     id003   hogwarts-rg2    Charms
Please select the lab to create: 0
LabName: MyName
MaxUsers: 30
```

## Structure of the example [Hogwarts.csv](https://github.com/Azure/azure-devtestlab/blob/master/samples/ClassroomLabs/Modules/Library/Tools/hogwarts.csv)
Item              | Description
----------------- | -------------
Id                | A unique id for the lab
Tags              | A set of tags applied to the lab.
ResourceGroupName | The name of the resource group that the lab account will be created in.  If the resource group doesn't already exist, it will be created.
Location          | The region that the Lab will be created in, if the lab doesn't already exist.  If the Lab (by LabName) already exists, this row is skipped.
LabAccountName    | The name of the Lab Account to be created, if the lab account doesn't already exist.
LabName           | The name of the Lab to be created
ImageName         | The image name that the lab will be based on.  Wildcards are accepted, but the ImageName field should match only 1 image.
AadGroupId        | The AadGroupId, used to connect the lab for syncing users.  Used to enable Microsoft Teams support for this lab.
MaxUsers          | Maximum number of users expected for the lab.
UsageQuota        | Maximum quota per student
UsageMode         | Type of usage expected for the lab.  Either "Restricted" - only those who are registered in the lab, or "Open" anyone.
SharedPassword    | Boolean value on whether the lab should use a shared password.  "True" means the lab uses a single shared password for the student's virtual machines, "False" means the students will be prompted to change their password on first login.
Size              | The Virtual Machine size to use for the Lab.  The options are:  Basic, MediumGPUVisualization, Performance, SmallGPUCompute, SmallGPUVisualization, Standard, Virtualization, Large .  Please see details below on how these map to the Azure Portal.
Title             | The title for the lab.
Descr             | The description for the lab.
UserName          | The default user name
Password          | The default password
LinuxRdp          | Set to "True" if the Virtual Machine requires Linux RDP, otherwise "False"
Emails            | Semicolon separated string of student emails to be added to the lab.  For example:  "bob@test.com;charlie@test.com"
LabOwnerEmails    | Semicolon separated string of teacher emails to be added to the lab.  The teacher will get Owner rights to the lab, and Reader rights to the Lab Account.  NOTE: this account must exist in Azure Active Directory tenant.
Invitation        | Note to include in the invitation email to students.  If you leave this field blank, invitation emails won't be sent during lab creation.
Schedules         | The name of the csv file that contains the schedule for this class.  For example: "charms.csv".  If left blank, a schedule won't be applied.

## Structure of the example [Charms.csv](https://github.com/Azure/azure-devtestlab/blob/master/samples/ClassroomLabs/Modules/Library/Tools/charms.csv)
Item              | Description
----------------- | -------------
Frequency         | How often, "Weekly" or "Once"
FromDate          | Start Date
ToDate            | End Date
StartTime         | Start Time
EndTime           | End Time
WeekDays          | Days of the week.  "Monday, Tuesday, Friday".  The days are comma seperated with the text. If Frequency is "Once" use an empty string "" 
TimeZoneId        | Time zone for the classes.  "Central Standard Time"
Notes             | Additional notes

## Virtual Machine Sizes
The Azure Portal shows sizes with a friendly name when creating a lab and the API takes specific strings that map to those friendly names.  Listed below is the mapping between these.  More information can be found in the [Lab Services Admin Guide](https://docs.microsoft.com/en-us/azure/lab-services/administrator-guide#vm-sizing).
Friendly Name                  | API Size               | Series
-------------------------------|------------------------|------------
Small                          | Basic                  | Standard_A2_v2
Medium                         | Standard               | Standard_A4_v2
Medium (nested virtualization) | Virtualization         | Standard_D4s_v3
Large                          | Large                  | Standard_A8_v2
Large (nested virtualization)  | Performance            | Standard_D8s_v3
Small GPU (visualization)      | SmallGPUVisualization  | Standard_NV6
Small GPU (Compute)            | SmallGPUCompute        | Standard_NC6
Medium GPU (visualization)     | MediumGPUVisualization | Standard_NV12