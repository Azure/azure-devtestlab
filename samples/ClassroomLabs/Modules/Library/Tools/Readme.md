# Bulk Lab Creation Script
The [LabCreator.ps1](https://github.com/Azure/azure-devtestlab/blob/master/samples/ClassroomLabs/Modules/Library/Tools/LabCreator.ps1) script enables users to create **Resource Groups**, **Lab Accounts** and **Labs** via commandline based on the contents of a CSV file.  When running the tool using a CSV input file, the script will create any resources that don't already exist.

## Getting Started
The [Bulk Lab Creation script](https://github.com/Azure/azure-devtestlab/tree/master/samples/ClassroomLabs/Modules/Library/Tools) is a stand-alone script that can be run from an authenticated Azure PowerShell session and requires [PowerShell](https://github.com/PowerShell/PowerShell/releases) and the [Azure PowerShell](https://docs.microsoft.com/en-us/powershell/azure/) module.  The script will automatically install the [ThreadJob](https://docs.microsoft.com/en-us/powershell/module/threadjob)  Powershell Module.
1. Get a local copy of the LabCreator.ps1 script by either [cloning the repo](https://github.com/Azure/azure-devtestlab.git) or by [downloading a copy](https://raw.githubusercontent.com/Azure/azure-devtestlab/master/samples/ClassroomLabs/Modules/Library/Tools/LabCreator.ps1)
1. Get a local copy of the example [hogwarts.csv](https://raw.githubusercontent.com/Azure/azure-devtestlab/master/samples/ClassroomLabs/Modules/Library/Tools/hogwarts.csv) file and example [charms.csv](https://raw.githubusercontent.com/Azure/azure-devtestlab/master/samples/ClassroomLabs/Modules/Library/Tools/charms.csv) file
1. Launch a PowerShell session
1. Ensure [Azure PowerShell](https://docs.microsoft.com/en-us/powershell/azure/install-az-ps) installed
1. Update the example CSV files to configure the resources to be created.  For addiitonal labs, create additional lines in the CSV file.  The CSV files can be modified diretly with Microsoft Excel.
1. Execute the Bulk Lab Creation script with the following commandline:
```powershell
.\LabCreator.ps1 -CsvConfigFile hogwarts.csv
```
## Structure of the example [Hogwarts.csv](https://github.com/Azure/azure-devtestlab/blob/master/samples/ClassroomLabs/Modules/Library/Tools/hogwarts.csv)
Item              | Description
----------------- | -------------
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
Size              | The Virtual Machine size to use for the Lab.  The options are:  Basic, MediumGPUVisualization, Performance, SmallGPUCompute, SmallGPUVisualization, Standard, Virtualization, Large
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
