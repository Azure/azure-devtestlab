# Introduction
These scripts will guide you to create and setup an Azure Lab Services lab account that is configured to run an [ethical hacking class](https://docs.microsoft.com/en-us/azure/lab-services/classroom-labs/class-type-ethical-hacking). Part 1 of these instructions will be to create the lab account on Azure. Part 2 of these instructions will be to prepare the template VM instance of the newly created lab to be used by your class.

- - - -

## Part 1 - Create a Lab Account 
This script will help create a Lab Account on your Azure account from your local machine.

> NOTE: Script must be executed using administrator privileges.

### Directions
1. Download the **Create-EthicalHacking-LabsAccount.ps1** PowerShell script onto the **local machine** through one of these ways:
     - Clone this repository 
     - Manually download the file
     - Use Invoke-WebRequest to download the file:
          > Invoke-WebRequest "https://raw.githubusercontent.com/Azure/azure-devtestlab/master/samples/ClassroomLabs/Scripts/EthicalHacking/Create-EthicalHacking-LabsAccount.ps1" -OutFile Create-EthicalHacking-LabsAccount.ps1
1. Open a PowerShell window.  Make sure that the window notes it is running under administrator privileges.
1. Navigate to **azure-devtestlab/samples/ClassroomLabs/Scripts**
1. Run `EthicalHacking/Create-EthicalHacking-LabsAccount.ps1`
     > NOTE: There are optional parameters you can pass to this script
     > - **Email** - *Provide an email address of someone else who should have contributor rights to the lab account*.
     > - **Username** - *Default is **AdminUser** but you can specify another username for the template VM*.
     > - **Password** - *Default is **P@ssword1** but you can specify another password for the template VM*.
     > - **Location** - *Default is **centralus** but you can specify another Azure location for where this lab account should live*.
     > - **ClassName** - *Default is **EthicalHacking** but you can specify another class name which will be a pre-fix used on Azure resources created by this script*.
1. Open the [Labs Portal](https://labs.azure.com) and login with your Azure credentials (or the [optional] e-mail address parameter if used) to see the lab account and lab created by this script.

- - - -

## Part 2 - Prepare Your Template Virtual Machine
This script will help prepare your template virtual machine for a ethical hacking class.  One virtual machine with a [Kali Linux](https://www.kali.org/) image is created.  Kali is a Linux distribution that includes tools for penetration testing and security auditing.  Another [Metasploitable](https://github.com/rapid7/metasploitable3) image is created.  The Rapid7 Metasploitable image is an image purposely configured with security vulnerabilities. You'll use this image to test and find issues. 

> NOTES:
> - This script is written for Windows Server OSes, not for Windows Client OSes.
> - Script must be executed using administrator privileges.

### Directions
1. Connect to template machine for your class.
1. Download the **Setup-EthicalHacking.ps1** PowerShell script onto the **Template Virtual Machine** through one of these ways
     - Clone this repository 
     - Manually download the file
     - Use Invoke-WebRequest to download the file:
          > Invoke-WebRequest "https://raw.githubusercontent.com/Azure/azure-devtestlab/master/samples/ClassroomLabs/Scripts/EthicalHacking/Setup-EthicalHacking.ps1" -OutFile Setup-EthicalHacking.ps1
1. Open a PowerShell window.  Make sure that the window notes it is running under administrator privileges.
1. Navigate to **azure-devtestlab/samples/ClassroomLabs/Scripts**
1. Run `HyperV/SetupForNestedVirtualization.ps1`, if not done already.  This installs the necessary features to create HyperV virtual machines. 
     > NOTE: The script may ask you to restart the machine and re-run it.  A note that the script is completed will show in the PowerShell window if no further action is needed.
1. Run `EthicalHacking/Setup-EthicalHacking.ps1`
