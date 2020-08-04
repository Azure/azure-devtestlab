<#
The MIT License (MIT)
Copyright (c) Microsoft Corporation  
Permission is hereby granted, free of charge, to any person obtaining a copy of this software and associated documentation files (the "Software"), to deal in the Software without restriction, including without limitation the rights to use, copy, modify, merge, publish, distribute, sublicense, and/or sell copies of the Software, and to permit persons to whom the Software is furnished to do so, subject to the following conditions:
The above copyright notice and this permission notice shall be included in all copies or substantial portions of the Software.  
THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE. 
.SYNOPSIS
This script is to add the device to a specific AD group

.LINK https://docs.microsoft.com/en-us/azure/lab-services/classroom-labs/how-to-connect-peer-virtual-network
.EXAMPLE
. ".\Join-AzLabADStudent_AddToADGroup.ps1"
#>

[CmdletBinding()]
param(
    [parameter(Mandatory = $false, ValueFromPipelineByPropertyName = $true, HelpMessage = "Domain User (e.g. CONTOSO\frbona or frbona@contoso.com). It must have permissions to add computers to the domain.")]
    [ValidateNotNullOrEmpty()]
    [string] $DomainUser = "vmuser@contosolabuniversity.com",

    [parameter(Mandatory = $false, ValueFromPipelineByPropertyName = $true, HelpMessage = "Password of the Domain User.")]
    [ValidateNotNullOrEmpty()]
    [string] $DomainPassword = "VirtualMachineUser6.,.",
    
    [parameter(Mandatory = $false, ValueFromPipelineByPropertyName = $true, HelpMessage = "Specific AD Group.")]
    [string]$ADGroup = "Computer Science 101 Lab"

)

###################################################################################################

# Default exit code
$ExitCode = 0

try {

    $ErrorActionPreference = "Stop"

    . ".\Utils.ps1"
    
    Write-LogFile "Trying to add the device into an AD Group"

    $adJoinStatus = Get-AzureADJoinStatus
    $azureAdJoined = ($adJoinStatus | Where-Object { $_.State -eq "AzureAdJoined" } | Select-Object -First 1).Status

    # Check if the device has been (Hybrid) Azure AD Joined
    if ($azureAdJoined -ine "YES") {
        Write-LogFile "Unable to enroll into MDM. Device is not Azure AD Joined."
        exit
    }

    $tenantName = ($adJoinStatus | Where-Object { $_.State -eq "TenantName" } | Select-Object -First 1).Status
    Write-LogFile "Device is Azure AD Joined to the tenant $tenantName"

    
    $azureAdPrt = ($adJoinStatus | Where-Object { $_.State -eq "AzureAdPrt" } | Select-Object -First 1).Status
    if ($azureAdPrt -ine "YES") {
        $username = [System.Security.Principal.WindowsIdentity]::GetCurrent().Name
        Write-LogFile "Unable to enroll into MDM. User does not have AzureADPrt (personal refresh token). Current user $username"
        exit
    }
    
    #Write-LogFile "Trying to enroll the device into the MDM service"
    #Join-DeviceMDM

    Write-LogFile "*****Get Device ****"
    #$device = ($adJoinStatus | Where-Object { $_.State -eq "DeviceId" } | Select-Object -First 1).Status
    $objectId = (Get-AzureADDevice -SearchString $env:COMPUTERNAME | Select-Object -First 1).ObjectId
    Write-LogFile "**** Device: $device ****"
    $group = (Get-AzureADGroup -SearchString $ADGroup | Select-Object -First 1).ObjectId
    Write-LogFile "**** Group: $group ****"
    Add-AzureADGroupMember -ObjectId $group -RefObjectId $device
    Write-LogFile "**** After Add ****"
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