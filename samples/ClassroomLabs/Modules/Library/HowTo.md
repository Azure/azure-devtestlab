# Az.LabServices Tutorial <!-- omit in TOC -->

Az.LabServices is a PowerShell module to simplify the management of [Azure Lab services](https://azure.microsoft.com/en-in/services/lab-services/). It provides composable functions to create, query, update and delete lab accounts, labs, VMs and Images.

- [Introduction](#introduction)
- [Import the module](#import-the-module)
- [Browse all the functions in the library](#browse-all-the-functions-in-the-library)
- [Publish a new lab](#publish-a-new-lab)
- [Query for lab accounts, labs and VMs](#query-for-lab-accounts-labs-and-vms)
- [Manage Users](#manage-users)
- [Set schedules](#set-schedules)
- [Remove objects](#remove-objects)
- [Give us feedback](#give-us-feedback)
  
## Introduction

If you want a quick overview of all the features, see this [scenario file](Scenarios/AllFeatures.ps1).

Many of the code snippets below might take a bit of time (minutes) to execute, especially the ones that create Azure resources.

You can pass the `-verbose` parameter to see some action on your screen, otherwise the snippets succeed silently.

## Import the module

First you need to save the [`Az.LabServices.psm1`](Az.LabServices.psm1) file in a directory on disk.

Then you need to open a Powershell console and import the module:

```powershell
cd DIRECTORY-WITH-MODULE
import-module ./Az.LabServices.psm1
```

## Browse all the functions in the library

As a quick way to see which Azure Lab Services capabilities are supported, type the following command in the console.

```powershell
Get-Command -Module Az.LabServices
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

We then need to find an image to base the lab on.

```powershell
$img = $la | Get-AzLabAccountGalleryImage | Where-Object {$_.name -like 'CentOS-Based*'}
```

Notice that you can also get the image from a shared gallery, by calling the `Get-AzLabAccountSharedImage` function instead of `Get-AzLabAccountGalleryImage`.

Once we have an image, we can create a new lab in the lab account. The parameters should be self-explanatory as they closely resemble the equally named parameters in the Azure Labs UI.

```powershell
$lab = $la | New-AzLab -LabName MyLab -Image $img -Size Basic -UsageQuotaInHours 20 -SharedPasswordEnabled -UserName 'Test0000' -Password 'test00000000' -LinuxRdpEnabled
```

Once all of the above is done, you can finally publish the lab:

```powershell
$lab = $lab | Publish-AzLab
```

If later on you need to modify some property of the lab (i.e. change number of users), you can use the `Set-AzLab` function.

If you want reusable functions that do all the steps above in one shot, look at the `New-AzLabSingle` function inside the [`LabCreator.ps1`](Tools/LabCreator.ps1) script.

## Query for lab accounts, labs and VMs

The library makes extensive use of [PowerShell pipelines](https://docs.microsoft.com/en-us/powershell/scripting/learn/understanding-the-powershell-pipeline?view=powershell-6) as a way to pass the most important object(s) to a function. This allows the creation of 'chains of functions' to perform multiple operations on an object.

The library contains a powerful query system, that allows you to retrieve objects (i.e. lab accounts, labs, VMs etc...) that can then be used as input in such functions chains.

For example, you can retrieve all the lab accounts in your subscription by the simple:

```powershell
Get-AzLabAccount
```

And then, through function composition, get all the labs as:

```powershell
Get-AzLabAccount | Get-AzLab
```

Or perhaps just the labs with certain name and/or resource group name patterns.

```powershell
$labs = Get-AzLabAccount | Get-AzLab -LabName *Lab
```

You can then use the resulting lab(s) as the start of a function chain. For example to get all the runnnig VMs:

```powershell
$vms = $labs | Get-AzLabVm -Status Running
```

A note of caution. Try to be as precise as possible in your query. The more you omit parameters or use `*`, the larger the set of VMs we need to retrieve to then apply the query on the client side. In most scenarios, that is not a problem, but if you have very many labs and VMs, it might be.

## Manage users

You can add users to one or multiple labs with:

```powershell
$labs | Add-AzLabUser -Emails @('user1@example.com', 'user2@example.com')
```

Once added, you can then send invitation emails to your lab users as below:

```powershell
$labs | Get-AzLabUser | Send-AzLabUserInvitationEmail -InvitationText 'You are invited to mylab'
```

## Set schedules

Setting a recurrent schedule for your class is done using the `New-AzLabSchedule` function:

```powershell
@(
    [PSCustomObject]@{Frequency='Weekly';FromDate=$today;ToDate = $end;StartTime='10:00';EndTime='11:00';Notes='Theory'}
    [PSCustomObject]@{Frequency='Weekly';FromDate=$tomorrow;ToDate = $end;StartTime='11:00';EndTime='12:00';Notes='Practice'}
) | ForEach-Object { $_ | New-AzLabSchedule -Lab $lab} | Out-Null
```

## Remove objects

The library contains function to remove all the kinds of objects created, i.e. `Remove-AzLabAccount`, `Remove-AzLab`, `Remove-AzLabSchedule`, `Remove-AzLabUser`.

Finally, let's clean up the resource group we created:

```powershell
Remove-AzureRmResourceGroup -Name DtlPS1 -Location "West Europe"
```

## Give us feedback

Feel free to give us feedback on the library [here](https://github.com/Azure/azure-devtestlab/issues).