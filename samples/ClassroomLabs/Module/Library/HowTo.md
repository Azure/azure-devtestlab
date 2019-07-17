# Az.AzureLabs Tutorial <!-- omit in TOC -->

Az.AzureLabs is a PowerShell module to simplify the management of [Azure Lab services](https://azure.microsoft.com/en-in/services/lab-services/). It provides composable functions to create, query, update and delete lab accounts, labs, VMs and Images.

- [Introduction](#introduction)
- [Import the module](#import-the-module)
- [Browse all the functions in the library](#browse-all-the-functions-in-the-library)
- [Publish a new lab](#publish-a-new-lab)
- [Modify a lab](#modify-a-lab)
- [Create a VM in the lab](#create-a-vm-in-the-lab)
- [Use custom images](#use-custom-images)
- [Query for labs and VMs](#query-for-labs-and-vms)
- [Remove labs and VMs](#remove-labs-and-vms)
- [Give us feedback](#give-us-feedback)
  
## Introduction

If you want a quick overview of all the features, see this [scenario file](Scenarios/AllFeatures.ps1).

Many of the code snippets below might take a bit of time (minutes) to execute, especially the ones that create Azure resources.

You can pass the `-verbose` parameter to see some action on your screen, otherwise the snippets succeed silently.

## Import the module

First you need to save the [`Az.AzureLabs.psm1`](Az.AzureLabs.psm1) file in a directory on disk.

Then you need to open a Powershell console and import the module:

```powershell
cd DIRECTORY-WITH-MODULE
import-module ./Az.AzureLabs.psm1
```

## Browse all the functions in the library

As a quick way to see which DevTestLabs capabilities are supported, type the following command in the console.

```powershell
Get-Command -Module Az.AzureLabs
```

## Publish a new lab

From now on, the tutorial assumes that you are signed in into Azure. If you are not, you can read about it [here](https://docs.microsoft.com/en-us/powershell/azure/authenticate-azureps?view=azps-2.1.0).

First, let's create a new Resource Group to host your lab.

```powershell
New-AzureRmResourceGroup -Name DtlPS1 -Location "West Europe"
```

Then create a new lab account in the resource group

```powerhsell
$la = New-AzLabAccount -ResourceGroupName DtlPS1 -LabAccountName TestAzLab
```

Then create a new lab in the lab account. The parameters should be self-explanatory as they closely resemble the equally named parameters in the Azure Labs UI.

```powershell
$lab = $la | New-AzLab -LabName MyLab -MaxUsers 2 -UsageQuotaInHours 20 -UserAccessMode Restricted -SharedPasswordEnabled
```

Once the lab is created, we need to add a template VM to it. A template VM needs an image to be based on. The whole process is exemplified below:

```powershell
$img = $la | Get-AzLabAccountGalleryImage | Where-Object {$_.name -like 'CentOS-Based*'}
$lab = $lab | New-AzLabTemplateVM -Image $img -Size 'Small' -Title 'My lab title' -Description 'My descr' -UserName 'Test0000' -Password 'test00000000' -LinuxRdpEnabled
```

Notice that you can also get the image from a shared gallery, by calling the `Get-AzLabAccountSharedImage` function instead of `Get-AzLabAccountGalleryImage`.

Once all of the above is done, you can finally publish the lab:

```powershell
$lab = $lab | Publish-AzLab
```

If later on you need to modify some property of the lab (i.e. change number of users), you can use the `Set-AzLab` function.

If you want reusable functions that do all the steps above in one shot, look at the `New-AzLabSingle` function inside the [`LabCreator.ps1`](Tools/LabCreator.ps1) script.

## Modify a lab

Now that you have a lab you might want to modify it in some way.

The library makes extensive use of [PowerShell pipelines](https://docs.microsoft.com/en-us/powershell/scripting/learn/understanding-the-powershell-pipeline?view=powershell-6) as a way to pass the most important object(s) to a function.

To modify a lab, you 'pipe in' the lab object that you created before and execute a function on it. The result is another lab object that you can again 'pipe in' into the next function.

This allows the creation of 'chains of functions' to perform multiple operations on an object.

Here is an example of one of such chains that sets various parameters for the lab we just created:

```powershell
$lab = $lab `
  | Dtl-AddUser -UserEmail 'lucabol@microsoft.com' `
  | Dtl-SetLabAnnouncement -Title 'I am here' -AnnouncementMarkDown 'yep' `
  | Dtl-SetLabSupport -SupportMarkdown "### Sample lab announcement header." `
  | Dtl-SetLabRdp -GatewayUrl 'Agtway@adomain.com' -ExperienceLevel 5 `
  | Dtl-SetLabShutdown -ShutdownTime '21:00' -TimeZoneId 'UTC' -ScheduleStatus 'Enabled' -NotificationSettings 'Enabled' `
      -TimeInIMinutes 50 -ShutdownNotificationUrl 'https://blah.com' -EmailRecipient 'blah@lab.com' `
  | Dtl-SetLabStartup -StartupTime '21:00' -TimeZoneId 'UTC' -WeekDays @('Monday') `
  | Dtl-AddLabRepo -ArtifactRepoUri 'https://github.com/lucabol/DTLWorkshop.git' `
      -artifactRepoSecurityToken '196ad1f5b5464de4de6d47705bbcab0ce7d323fe'
```

Notice that the return value of the chain is a lab object that you can then use again as input to another chain.

Here is not the place to describe all functions and all parameters. They should be self-explaining if you are familiar with DevTest Labs. Remember that you can always ask for help with:

```powershell
get-help Dtl-SetLabShutdown
```

Or simply type `-` and the `TAB` key to cycle through all of them.

## Create a VM in the lab

There are many possible ways to create a VM in DevTest Labs. This is reflected by the different parameters that can be passed to the `Dtl-NewVm` function. The system gives you an error you when you pass the wrong set.

`Dtl-NewVm` is an example of a function that changes the object that 'flows through' the pipeline. It takes lab object(s) as input and produces VM object(s) as output.

You can then form chains of functions to operate over the just created VM, as in the following example.

```powershell
$lab | Dtl-NewVm -VmName ("vm" + (Get-Random)) -Size 'Standard_A4_v2' -Claimable -UserName 'bob' -Password 'aPassword341341' `
      -OsType Windows -Sku '2012-R2-Datacenter' -Publisher 'MicrosoftWindowsServer' -Offer 'WindowsServer' `
      -AsJob `
  | Receive-Job -Wait `
  | Dtl-StartVm `
  | Dtl-ApplyArtifact -RepositoryName 'Public Artifact Repo' -ArtifactName 'windows-7zip' `
  | Dtl-SetAutoStart `
  | Dtl-SetVmShutdown -ShutdownTime '20:00' -TimeZoneId 'UTC' `
  | Dtl-ClaimVm `
  | Dtl-StopVm
```

One interesting aspect of the code above is the use of the `-asJob` parameter.

This is the standard way in PowerShell to execute commands in parallel. Imagine if the `$lab` variable contained multiple labs, perhaps as result of a query (to be described later). Then the chain above would create a VM in each one of the labs in parallel (and start them, apply artifacts, etc ...).

Most 'expensive' commands in the library support the `-asJob` parameter so they can be easily 'parallelized' in this fashion.

## Use custom images

The library supports the creation and use of custom images, as in the code snippet below. Read more about them [here](https://docs.microsoft.com/en-us/azure/lab-services/devtest-lab-create-custom-image-from-vm-using-portal).

```powershell
$customImage = $lab `
  | Dtl-NewVm -VmName ("cvm" + (Get-Random)) -Size 'Standard_A4_v2' -Claimable -UserName 'bob' -Password 'aPassword341341' `
    -OsType Windows -Sku '2012-R2-Datacenter' -Publisher 'MicrosoftWindowsServer' -Offer 'WindowsServer' `
  | Dtl-NewCustomImage -ImageName ("im" + (Get-Random)) -ImageDescription 'Created using Azure DevTest Labs PowerShell library.'

$lab | Dtl-NewVm -CustomImage $customImage -VmName ('cvm2' + (Get-Random)) -Size 'Standard_A4_v2' -OsType Windows | Out-Null
```

## Query for labs and VMs

The library contains a powerful query system, that allows you to retrieve objects (i.e. labs, VMs, custom images, etc...) that can then be used as input in functions chains.

For example, you can get all the labs in your subscription by:

```powershell
Dtl-GetLab
```

Or just the labs with certain name and/or resource group names patterns.

```powershell
$labs = Dtl-GetLab -ResourceGroupName Dtl* -Name *Lab
```

You can then use the resulting lab(s) as the start of a function chain. For example to get all VMs with names staring with `vm` type:

```powershell
$labs | Dtl-GetVM -name vm*
```

As a final example, to retrieve all the stopped VMs in all your labs you write:

```powershell
Dtl-GetLab | Dtl-GetVm -status Stopped
```

A note of caution. Try to be as precise as possible in your query. The more you omit parameters or use `*`, the larger the set of VMs we need to retrieve to then apply the query on the client side. In most scenarios, that is not a problem, but if you have very many labs and VMs, it might be.

## Remove labs and VMs

You can remove labs and vms with the appropriately named `Dtl-RemoveLab` and `Dtl-RemoveVm`.

As always, they can be applied to multiple labs/vms in a pipeline, allowing you to easily perform batch operations in parallel.

```powershell
Dtl-GetLab -Name Test* -ResourceGroupName Test* | Dtl-GetVM | Dtl-RemoveVm -asJob | Receive-Job -Wait
```

Finally, let's clean up the resource group we created:

```powershell
Remove-AzureRmResourceGroup -Name DtlPS1 -Location "West Europe"
```

## Give us feedback

Feel free to give us feedback on the library [here](https://github.com/Azure/azure-devtestlab/issues).