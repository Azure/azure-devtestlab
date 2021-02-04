<#
The MIT License (MIT)
Copyright (c) Microsoft Corporation  
Permission is hereby granted, free of charge, to any person obtaining a copy of this software and associated documentation files (the "Software"), to deal in the Software without restriction, including without limitation the rights to use, copy, modify, merge, publish, distribute, sublicense, and/or sell copies of the Software, and to permit persons to whom the Software is furnished to do so, subject to the following conditions:
The above copyright notice and this permission notice shall be included in all copies or substantial portions of the Software.  
THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE. 
.SYNOPSIS
This script is part of the scripts chain for joining a student VM to an Active Directory domain. It applies new DNS settings for the AD Domain Services Server and performs the actual join to the AD Domain. Then it schedules a script to add students to the VM after reboot.
.LINK https://docs.microsoft.com/en-us/azure/lab-services/classroom-labs/how-to-connect-peer-virtual-network
.PARAMETER LabAccountResourceGroupName
Resource group name of Lab Account.
.PARAMETER LabAccountName
Name of Lab Account.
.PARAMETER LabName
Name of Lab.
.PARAMETER DomainServiceAddress
One or more AD Domain Services Server addresses.
.PARAMETER Domain
Domain Name (e.g. contoso.com).
.PARAMETER LocalUser
Local User created when setting up the Lab.
.PARAMETER DomainUser
Domain User (e.g. CONTOSO\frbona or frbona@contoso.com). It must have permissions to add computers to the domain.
.PARAMETER LocalPassword
Password of the Local User.
.PARAMETER DomainPassword
Password of the Domain User.
.PARAMETER EnrollMDM
Whether to enroll the VMs to Intune (for Hybrid AD only).
.PARAMETER CurrentTaskName
Name of the task this script is run from (optional).
.NOTES
.EXAMPLE
. ".\Join-AzLabADStudent_JoinVm.ps1" `
    -LabAccountResourceGroupName 'labaccount-rg' `
    -LabAccountName 'labaccount' `
    -LabName 'Mobile App Development' `
    -DomainServiceAddress '10.0.23.5','10.0.23.6' `
    -Domain 'contoso.com' `
    -LocalUser 'localUser' `
    -DomainUser 'domainUser' `
    -LocalPassword 'localPassword' `
    -DomainPassword 'domainPassword' `
    -OUPath 'OU=OrgUnit,DC=domain,DC=Domain,DC=com' `
    -EnrollMDM
#>

[CmdletBinding()]
param(
    [parameter(Mandatory = $true, HelpMessage = "Resource group name of Lab Account.", ValueFromPipeline = $true)]
    [ValidateNotNullOrEmpty()]
    $LabAccountResourceGroupName,

    [parameter(Mandatory = $true, HelpMessage = "Name of Lab Account.", ValueFromPipeline = $true)]
    [ValidateNotNullOrEmpty()]
    $LabAccountName,
  
    [parameter(Mandatory = $true, ValueFromPipelineByPropertyName = $true, HelpMessage = "Name of Lab.")]
    [ValidateNotNullOrEmpty()]
    $LabName,

    [parameter(Mandatory = $true, ValueFromPipelineByPropertyName = $true, HelpMessage = "One or more AD Domain Services Server addresses.")]
    [ValidateNotNullOrEmpty()]
    [string[]] $DomainServiceAddress,

    [parameter(Mandatory = $true, ValueFromPipelineByPropertyName = $true, HelpMessage = "Domain Name (e.g. contoso.com).")]
    [ValidateNotNullOrEmpty()]
    [string] $Domain,

    [parameter(Mandatory = $true, ValueFromPipelineByPropertyName = $true, HelpMessage = "Local User created when setting up the Lab.")]
    [ValidateNotNullOrEmpty()]
    [string] $LocalUser,

    [parameter(Mandatory = $true, ValueFromPipelineByPropertyName = $true, HelpMessage = "Domain User (e.g. CONTOSO\frbona or frbona@contoso.com). It must have permissions to add computers to the domain.")]
    [ValidateNotNullOrEmpty()]
    [string] $DomainUser,

    [parameter(Mandatory = $true, ValueFromPipelineByPropertyName = $true, HelpMessage = "Password of the Local User.")]
    [ValidateNotNullOrEmpty()]
    [string] $LocalPassword,

    [parameter(Mandatory = $true, ValueFromPipelineByPropertyName = $true, HelpMessage = "Password of the Domain User.")]
    [ValidateNotNullOrEmpty()]
    [string] $DomainPassword,

    [parameter(Mandatory = $true, ValueFromPipelineByPropertyName = $true, HelpMessage = "Specific Organization Path.")]
    [string]
    $OUPath = "no-op",
    
    [parameter(Mandatory = $false, ValueFromPipelineByPropertyName = $true, HelpMessage = "Whether to enroll the VMs to Intune (for Hybrid AD only)")]
    [switch]
    $EnrollMDM = $false,

    [parameter(Mandatory = $false, ValueFromPipelineByPropertyName = $true, HelpMessage = "Name of the task this script is run from (optional).")]
    [string]
    $CurrentTaskName
)

###################################################################################################

# Default exit code
$ExitCode = 0

try {

    $ErrorActionPreference = "Stop"

    . ".\Utils.ps1"

    # Check if VM has already been domain joined
    $computerDomain = (Get-WmiObject Win32_ComputerSystem).Domain
    if ($computerDomain -ieq $Domain) {
        # Computer is already joined to a domain
        Write-LogFile "VM has already been joined to the domain '$Domain'"    
        exit
    }

    Write-LogFile "Changing DNS settings"
    $netAdapter = Get-NetAdapter -Physical
    Set-DnsClientServerAddress -InterfaceAlias $netAdapter.Name -ServerAddresses $DomainServiceAddress

    $secureDomainPassword = ConvertTo-SecureString $DomainPassword -AsPlainText -Force
    $domainCredential = New-Object System.Management.Automation.PSCredential ($DomainUser, $secureDomainPassword)

    # Domain join the current VM
    Write-LogFile "Joining computer '$env:COMPUTERNAME' to domain '$Domain'"
    if ($OUpath -ne "no-op") {
        Add-Computer -DomainName $Domain -Credential $domainCredential -OUPath $OUPath -Force
    }
    else {
        Add-Computer -DomainName $Domain -Credential $domainCredential -Force
    }
    Write-LogFile "This VM has successfully been joined to the AD domain '$Domain'"

    # Register Add Student script to run at next startup
    Write-LogFile "Registering the '$JoinAzLabADStudentAddStudentScriptName' script to run at next startup"
    Register-AzLabADStudentTask `
        -LabAccountResourceGroupName $LabAccountResourceGroupName `
        -LabAccountName $LabAccountName `
        -LabName $LabName `
        -DomainServiceAddress $DomainServiceAddress `
        -Domain $Domain `
        -LocalUser $LocalUser `
        -DomainUser $DomainUser `
        -LocalPassword $LocalPassword `
        -DomainPassword $DomainPassword `
        -OUPath $OUPath `
        -ScriptName $JoinAzLabADStudentAddStudentScriptName `
        -EnrollMDM:$EnrollMDM

    Write-LogFile "Restarting VM to apply changes"
    Restart-Computer -Force
}

catch
{
    $message = $Error[0].Exception.Message
    if ($message) {
        Write-LogFile "`nERROR: $message"
    }

    Write-LogFile "`nThe script failed to run.`n"

    # Important note: Throwing a terminating error (using $ErrorActionPreference = "stop") still returns exit 
    # code zero from the powershell script. The workaround is to use try/catch blocks and return a non-zero 
    # exit code from the catch block. 
    $ExitCode = -1
}

finally {

    Write-LogFile "Exiting with $ExitCode" 
    exit $ExitCode
}