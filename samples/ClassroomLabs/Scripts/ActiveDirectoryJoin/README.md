# Azure Lab Services - Active Directory Domain Join

These scripts can be used to join Lab Services VMs to an Active Directory Domain.
VMs can be joined to:
- **On-premises AD Domains**
- **Hybrid AD Domains**: An on-prem AD which is connected to an Azure Active Directory through [Azure AD Connect](https://docs.microsoft.com/en-us/azure/active-directory/hybrid/how-to-connect-install-prerequisites). AD Domain Services is installed on a on-prem server. Applies also to federated domains.
- **Azure AD DS Domains**: For full-cloud AD (Azure AD + Azure AD DS) or Hybrid AD with secondary Domain Services on Azure.

## Prerequisites
1) 2 options:
    * Wire up your on-prem Domain Controller network to an Azure VNet, either with a [site-to-site VPN gateway](https://docs.microsoft.com/en-us/azure/vpn-gateway/vpn-gateway-about-vpngateways) or [ExpressRoute](https://docs.microsoft.com/en-us/azure/expressroute/expressroute-introduction).
    * Create a secondary managed domain on top of your on-prem one with [Azure AD DS (PaaS)](https://docs.microsoft.com/en-us/azure/active-directory-domain-services/tutorial-create-instance).
2) [Peer the Lab Account](https://docs.microsoft.com/en-us/azure/lab-services/classroom-labs/how-to-connect-peer-virtual-network) with the connected VNet.
3) Create a new Lab (Labs created prior to the VNet peering are not supported). Enable the option **Use same password for all virtual machines**.
4) On the Template VM:
    * Install the [Azure PowerShell Module](https://docs.microsoft.com/en-us/powershell/azure/install-az-ps?view=azps-2.8.0)
    * Connect to your Azure Account: ```Connect-AzAccount```
    * Set the default subscription to the one of the Lab Account: ```Select-AzSubscription -SubscriptionID <SUB_ID>```
5) The Join-AzLabADTemplate script will publish the template automatically.

## Usage

From the Template VM:

```powershell
$DomainServiceAddress = '<PRIMARY_DS_IP>','<SECONDARY_DS_IP>'
$Domain = "contosounilab.com"
$LocalUser = "localuser"
$DomainUser = "domainuser@contosounilab.com"
$LocalPassword = "<LOCAL_PASSWORD>"
$DomainPassword = "<DOMAIN_PASSWORD>"
# Optional
$OUPath = "OU=test,DC=onmicrosoft,DC=com"
#

. ".\Join-AzLabADTemplate.ps1" `
    -DomainServiceAddress $DomainServiceAddress `
    -Domain $Domain `
    -LocalUser $LocalUser `
    -DomainUser $DomainUser `
    -LocalPassword $LocalPassword `
    -DomainPassword $DomainPassword `
    -OUPath $OUPath
    -EnrollMDM
```

### Parameters

#### ***DomainServiceAddress***
1 or more IP addresses of the Servers where AD DS is installed.

*For on-prem AD DS Servers:*
![On-prem AD DS](./img/On-prem%20AD%20DS%20Server.png)

*For Azure AD DS (PaaS):*
![Azure AD DS (PaaS)](./img/Azure%20AD%20DS.png)

#### ***Domain***
Name of the AD domain (e.g. contoso.com).

#### ***LocalUser***
Local Account name for the Template VM (the one specified at Lab creation).

#### ***DomainUser***
Domain Account name (e.g. CONTOSO\frbona or frbona@contoso.com). The account must have permissions to add computers to the AD domain.

#### ***LocalPassword***
Local Account password for the Template VM (the one specified at Lab creation).

#### ***DomainPassword***
Domain account password.

#### ***OUPath***
(Optional) Organization Unit for the specific domain.

#### ***EnrollMDM***
(Optional) Whether to enroll the VMs to Intune (for Hybrid AD only).

## Template VM
### ***Join-AzLabADTemplate***
Main script to be run from the Template VM. It gets details on the currently running Template VM and Lab. It then schedules the scripts chain starting with ***Join-AzLabADStudent_RenameVm.ps1*** and publishes the Lab.

**Note**: Only the Student VMs are domain-joined. Template VM is used to run the ***Join-AzLabADTemplate.ps1*** script and trigger the next chain of scripts in the Student VMs.

## Scripts Chain
### ***Join-AzLabADStudent_RenameVm (step I)***
Gets the details on the currently running Student VM and renames the computer with a unique name. It then schedules the startup script ***Join-AzLabADStudent_JoinVm.ps1*** to run at next boot.

### ***Join-AzLabADStudent_JoinVm (step II)***
Updates the DNS settings based on the Domain Services address/es and performs the actual join of the computer to the domain. It then schedules the startup script ***Join-AzLabADStudent_AddStudent.ps1*** to run at next boot.

### ***Join-AzLabADStudent_AddStudent (step III)***
Checks whether the VM has been claimed by a student and eventually adds the student to the local RDP group.

### ***Join-AzLabADStudent_EnrollMDM (step IV)***
Checks the device is Azure AD joined. If so, it enrolls the VM to Intune using the user AAD credentials.

**Note**: Applies only to Hybrid AD joined devices. Student must be assigned a valid Intune license. Other requirements for Intune can be found [here](https://docs.microsoft.com/en-us/windows/client-management/mdm/enroll-a-windows-10-device-automatically-using-group-policy#verify-auto-enrollment-requirements-and-settings). 

### ***Set-AzLabADVms (optional)***
Optional script to be run from the Template VM. It spins up all the VMs leaving enough time for the domain join scripts to be executed before shutting down the VMs.

### ***Utils.ps1***
Utility functions and extensions to the Az.LabServices module.

### ***Set-AzLabCapacity***
Optional script to be run from the Template VM.  The script will change the lab VM capacity.

## Notes
- The script currently supports only Windows 10.
- The domain join happens at the first boot of the Student VM. Approximately 2-3 minutes are required for the scripts to execute.
- Both unclaimed and claimed VMs are joined to the AD domain. For claimed VMs, students can use their university credentials. They can still use the local account credentials if professors provide those credentials.
- At Lab creation, enabling the option **Use same password for all virtual machines** is preferable. This way, students are not prompted to pick a new password and can use straightaway their university credentials.