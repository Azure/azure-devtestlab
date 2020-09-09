<#
The MIT License (MIT)
Copyright (c) Microsoft Corporation  
Permission is hereby granted, free of charge, to any person obtaining a copy of this software and associated documentation files (the "Software"), to deal in the Software without restriction, including without limitation the rights to use, copy, modify, merge, publish, distribute, sublicense, and/or sell copies of the Software, and to permit persons to whom the Software is furnished to do so, subject to the following conditions:
The above copyright notice and this permission notice shall be included in all copies or substantial portions of the Software.  
THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE. 
.SYNOPSIS
This script is part of the scripts chain for joining a student VM to an Active Directory domain. It enroll the computer to the MDM service.
TODO Ideally this can be abstracted based on the MDM Service, e.g Intune (on-cloud) vs SCCM (on-prem)
.LINK https://docs.microsoft.com/en-us/azure/lab-services/classroom-labs/how-to-connect-peer-virtual-network
.EXAMPLE
. ".\Join-AzLabADStudent_IntuneEnrollment.ps1"
#>

###################################################################################################

# Default exit code
$ExitCode = 0

try {

    $ErrorActionPreference = "Stop"

    . ".\Utils.ps1"
    
    Write-LogFile "Trying to enroll the device into the MDM service"

    $adJoinStatus = Get-AzureADJoinStatus
    $azureAdJoined = ($adJoinStatus | Where-Object { $_.State -eq "AzureAdJoined" } | Select-Object -First 1).Status

    # Check if the device has been (Hybrid) Azure AD Joined
    if ($azureAdJoined -ine "YES") {
        exit
    }

    $tenantName = ($adJoinStatus | Where-Object { $_.State -eq "TenantName" } | Select-Object -First 1).Status
    Write-LogFile "Device is Azure AD Joined to the tenant $tenantName"

    # TODO Check whether the AzureAdPrt token has been requested.
    # Without the token we cannot proceed with the Intune enrollment.
    # The whole token acquisition process documented here: https://jairocadena.com/2016/01/18/how-domain-join-is-different-in-windows-10-with-azure-ad/
    
    Write-LogFile "Trying to enroll the device into the MDM service"
    Join-DeviceMDM
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