# University repository
This repository has been created to collect the required material to set up DevTest Labs in Univerisities. This is useful both for IT admin and students because the former won't have to maintain physical machines, the latter will always have fresh machines available both for classes and self-service usage.


## Scenario Scripts Folder
This folder contains:
- [Powershell scripts file which needs to be run either via Console or via Automation account on Azure to set up the environments for the imagined scenarios.](ScenarioScripts)
    - [Add-AzureDtlVM](ScenarioScripts/Add-AzureDtlVM.ps1): This script adds the specified number of Azure virtual machines to a DevTest Lab.
    - [Add-AzureDtlVMAutoVar](ScenarioScripts/Add-AzureDtlVMAutoVar.ps1): This script adds the number of Azure virtual machines in the DevTest Lab by reading some parameters from AutomationVariable.
    - [Add-GroupPermissionsDevTestLab](ScenarioScripts/Add-GroupPermissionsDevTestLab.ps1): This script adds the specified role to the AD Group in the DevTest Lab.
    - [Common](ScenarioScripts/Common.ps1): This script contains many useful functions for the other scripts.
    - [DeallocateStoppedVM](ScenarioScripts/DeallocateStoppedVM.ps1): This script deallocates every stopped Azure virtual machines.
    - [Manage-AzureDtlFixedPool](ScenarioScripts/Manage-AzureDtlFixedPool.ps1): This script guarantees that the Virtual Machine pool of the Lab equals to the PoolSize specified as Azure Tag of Lab.
    - [Remove-AzureDtlLabVMs](ScenarioScripts/Remove-AzureDtlLabVMs.ps1): This script guarantees that the Virtual Machine pool of the Lab equals to the PoolSize specified as Azure Tag of Lab.
    - [Remove-AzureDtlVM](ScenarioScripts/Remove-AzureDtlVM.ps1): This script deletes every Azure virtual machines in the DevTest Lab.
    - [Remove-GroupPermissionsDevTestLab](ScenarioScripts/Remove-GroupPermissionsDevTestLab.ps1): This script removes the specified role from the AD Group in the DevTest Lab.
    - [Test-AzureDtlVMs](ScenarioScripts/Test-AzureDtlVMs.ps1): Given LabName and LabSize, this script verifies how many Azure virtual machines are inside the DevTest Lab and throws an error inside the logs when the number is greater or lower than size +/- VMDelta. 

## Roles Foler
- [Roles folder which contains the json file which specifies the actions that a University user can take on a VM](Roles)

## Shutdown Scripts folder
- [Shutdown scripts folder which contains the scripts to automatically shutdown a VM if it's not used for a certain period of time](Shutdown%20Scripts)
    - [LoadIdleScript](Shutdown%20Scripts/LoadIdleScript.ps1): This script creates a task inside Windows Task Scheduler getting a file script from a blob storage.
    - [ShutdownOnIdleV2](Shutdown%20Scripts/ShutdownOnIdleV2.ps1): This script shutdowns the machine if the user hasn't been active.
  
## Simplified JS portal folder:   
- [Simplifies JS portal contains the files needed to set a simplified portal for the students to claim a VM in an easier way](SimplifiedJSPortal)

## Creating the appropriate Azure credential file to run the scripts from command line
In 'powershell' do the following:

    Login-AzureRmAccount
    Set-AzureRmContext -SubscriptionId "XXXXX-XXXX-XXXX"
    Save-AzureRMProfile -Path "$env:APPDATA\AzProfile.txt"

This saves the credentials file in the location on disk where the script look for by default.
