# Az.DevTestLabs Tutorial <!-- omit in TOC -->

Az.DevTestLabs is a PowerShell module to simplify the management of [Azure DevTest Labs](https://azure.microsoft.com/en-in/services/devtest-lab/). It provides composable functions to create, query, update and delete labs, VMs, Custom Images and Environments.

- [Introduction](#introduction)
- [Import the module](#import-the-module)
- [Browse all the functions in the library](#browse-all-the-functions-in-the-library)
- [Create a new lab](#create-a-new-lab)
- [Modify a lab](#modify-a-lab)
- [Create a VM in the lab](#create-a-vm-in-the-lab)
- [Use custom images](#use-custom-images)
- [Query for labs and VMs](#query-for-labs-and-vms)
- [Remove labs and VMs](#remove-labs-and-vms)
- [Give us feedback](#give-us-feedback)
  
## Introduction

If you want a quick overview of all the features, see this [scenario file](https://github.com/Azure/azure-devtestlab/blob/master/samples/DevTestLabs/Modules/Library/Scenarios/ScenarioAllFeatures.ps1).

Many of the code snippets below might take a bit of time (minutes) to execute, especially the ones that create Azure resources.

You can pass the `-verbose` parameter to see some action on your screen, otherwise the snippets succeed silently.

## Import the module

First you need to save the [`Az.DevTestLabs2.psm1`](https://github.com/Azure/azure-devtestlab/blob/master/samples/DevTestLabs/Modules/Library/Az.DevTestLabs2.psm1) file in a directory on disk.

Then you need to open a Powershell console and import the module:

```powershell
cd DIRECTORY-WITH-MODULE
import-module ./Az.DevTestLabs2.psm1
```

## Browse all the functions in the library

As a quick way to see which DevTestLabs capabilities are supported, type the following command in the console.

```powershell
Get-Command -Module Az.DevTestLabs2 | where-object {$_.Name -like '*AzDtl*'}
```

## Create a new lab

From now on, the tutorial assumes that you are signed in into Azure. If you are not, you can read about it [here](https://docs.microsoft.com/en-us/powershell/azure/authenticate-azureps?view=azps-2.1.0).

First, let's create a new Resource Group to host your lab.

```powershell
New-AzureRmResourceGroup -Name DtlPS1 -Location "West Europe"
```

Then create a new lab in the resource group.

```powershell
$lab = New-AzDtlLab -Name MyLab -ResourceGroupName DtlPS1
```

## Modify a lab

Now that you have a lab you might want to modify it in some way.

The library makes extensive use of [PowerShell pipelines](https://docs.microsoft.com/en-us/powershell/scripting/learn/understanding-the-powershell-pipeline?view=powershell-6) as a way to pass the most important object(s) to a function.

To modify a lab, you 'pipe in' the lab object that you created before and execute a function on it. The result is another lab object that you can again 'pipe in' into the next function.

This allows the creation of 'chains of functions' to perform multiple operations on an object.

Here is an example of one of such chains that sets various parameters for the lab we just created:

```powershell
$lab = $lab `
  | Add-AzDtlUser -UserEmail 'lucabol@microsoft.com' `
  | Set-AzDtlLabAnnouncement -Title 'I am here' -AnnouncementMarkDown 'yep' `
  | Set-AzDtlLabSupport -SupportMarkdown "### Sample lab announcement header." `
  | Set-AzDtlLabRdpSettings -GatewayUrl 'Agtway@adomain.com' -ExperienceLevel 5 `
  | Set-AzDtlLabShutdownPolicy -ShutdownTime '21:00' -TimeZoneId 'UTC' -ScheduleStatus 'Enabled' -NotificationSettings 'Enabled' `
      -TimeInIMinutes 50 -ShutdownNotificationUrl 'https://blah.com' -EmailRecipient 'blah@lab.com' `
  | Set-AzDtlLabStartupSchedule -StartupTime '21:00' -TimeZoneId 'UTC' -WeekDays @('Monday') `
  | Add-AzDtlLabArtifactRepository -ArtifactRepoUri 'https://github.com/lucabol/DTLWorkshop.git' `
      -artifactRepoSecurityToken '196ad1f5b5464de4de6d47705bbcab0ce7d323fe'
```

Notice that the return value of the chain is a lab object that you can then use again as input to another chain.

Here is not the place to describe all functions and all parameters. They should be self-explaining if you are familiar with DevTest Labs. Remember that you can always ask for help with:

```powershell
get-help Set-AzDtlLabShutdownPolicy
```

Or simply type `-` and the `TAB` key to cycle through all of them.

## Create a VM in the lab

There are many possible ways to create a VM in DevTest Labs. This is reflected by the different parameters that can be passed to the `New-AzDtlVm` function. The system gives you an error you when you pass the wrong set.

`New-AzDtlVm` is an example of a function that changes the object that 'flows through' the pipeline. It takes lab object(s) as input and produces VM object(s) as output.

You can then form chains of functions to operate over the just created VM, as in the following example.

```powershell
$lab | New-AzDtlVm -VmName ("vm" + (Get-Random)) -Size 'Standard_A4_v2' -Claimable -UserName 'bob' -Password 'aPassword341341' `
      -OsType Windows -Sku '2012-R2-Datacenter' -Publisher 'MicrosoftWindowsServer' -Offer 'WindowsServer' `
      -AsJob `
  | Receive-Job -Wait `
  | Start-AzDtlVm `
  | Set-AzDtlVmArtifact -RepositoryName 'Public Artifact Repo' -ArtifactName 'windows-7zip' `
  | Set-AzDtlVmAutoStart `
  | Set-AzDtlVmShutdownSchedule -ShutdownTime '20:00' -TimeZoneId 'UTC' `
  | Invoke-AzDtlVmClaim `
  | Stop-AzDtlVmStop
```

One interesting aspect of the code above is the use of the `-asJob` parameter.

This is the standard way in PowerShell to execute commands in parallel. Imagine if the `$lab` variable contained multiple labs, perhaps as result of a query (to be described later). Then the chain above would create a VM in each one of the labs in parallel (and start them, apply artifacts, etc ...).

Most 'expensive' commands in the library support the `-asJob` parameter so they can be easily 'parallelized' in this fashion.

## Use custom images

The library supports the creation and use of custom images, as in the code snippet below. Read more about them [here](https://docs.microsoft.com/en-us/azure/lab-services/devtest-lab-create-custom-image-from-vm-using-portal).

```powershell
$customImage = $lab `
  | New-AzDtlVm -VmName ("cvm" + (Get-Random)) -Size 'Standard_A4_v2' -Claimable -UserName 'bob' -Password 'aPassword341341' `
    -OsType Windows -Sku '2012-R2-Datacenter' -Publisher 'MicrosoftWindowsServer' -Offer 'WindowsServer' `
  | New-AzDtlCustomImageFromVm -ImageName ("im" + (Get-Random)) -ImageDescription 'Created using Azure DevTest Labs PowerShell library.'

$lab | New-AzDtlVm -CustomImage $customImage -VmName ('cvm2' + (Get-Random)) -Size 'Standard_A4_v2' -OsType Windows | Out-Null
```

## Query for labs and VMs

The library contains a powerful query system, that allows you to retrieve objects (i.e. labs, VMs, custom images, etc...) that can then be used as input in functions chains.

For example, you can get all the labs in your subscription by:

```powershell
Get-AzDtlLab
```

Or just the labs with certain name and/or resource group names patterns.

```powershell
$labs = Get-AzDtlLab -ResourceGroupName Dtl* -Name *Lab
```

You can then use the resulting lab(s) as the start of a function chain. For example to get all VMs with names staring with `vm` type:

```powershell
$labs | Get-AzDtlVm -name vm*
```

As a final example, to retrieve all the stopped VMs in all your labs you write:

```powershell
Get-AzDtlLab | Get-AzDtlVm -status Stopped
```

A note of caution. Try to be as precise as possible in your query. The more you omit parameters or use `*`, the larger the set of VMs we need to retrieve to then apply the query on the client side. In most scenarios, that is not a problem, but if you have very many labs and VMs, it might be.

## Remove labs and VMs

You can remove labs and vms with the appropriately named `Remove-AzDtlLab` and `Remove-AzDtlVm`.

As always, they can be applied to multiple labs/vms in a pipeline, allowing you to easily perform batch operations in parallel.

```powershell
Get-AzDtlLab -Name Test* -ResourceGroupName Test* | Get-AzDtlVm | Remove-AzDtlVm -asJob | Receive-Job -Wait
```

Finally, let's clean up the resource group we created:

```powershell
Remove-AzureRmResourceGroup -Name DtlPS1 -Location "West Europe"
```

## Aliases

The library also contains a set of aliases that you can use instead of the commands above. To see what they are type.

```powershell
Get-Command -Module Az.DevTestLabs2 | foreach { Get-Alias -Definition $_.name -ea SilentlyContinue }
```

## Give us feedback

Feel free to give us feedback on the library [here](https://github.com/Azure/azure-devtestlab/issues).