<#
The MIT License (MIT)
Copyright (c) Microsoft Corporation  
Permission is hereby granted, free of charge, to any person obtaining a copy of this software and associated documentation files (the "Software"), to deal in the Software without restriction, including without limitation the rights to use, copy, modify, merge, publish, distribute, sublicense, and/or sell copies of the Software, and to permit persons to whom the Software is furnished to do so, subject to the following conditions:
The above copyright notice and this permission notice shall be included in all copies or substantial portions of the Software.  
THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE. 
.SYNOPSIS
This script mimics what is done when lab user 'Connect' button for a lab virtual machine.  Please not this script is provided as a diagnostic tool only.
.PARAMETER LabMachineIpOrFqdn
The IP or FQDN of lab machine.  
.PARAMETER MachinePort
Port on which to reach the lab vm.  By default port is 3389.  If using the SharedIP feature, then the port will be different.

.EXAMPLE
.\Connect-VirtualMachine.ps1 -LabMachineIpOrFqdn {machine-name}.{location}.cloudapp.azure.com -GatewayHostname gw.contoso.com -FunctionKey {functionkey}
.\Connect-VirtualMachine.ps1 -LabMachineIpOrFqdn {machine-name}.{location}.cloudapp.azure.com -MachinePort 3389 -GatewayHostname gw.contoso.com -FunctionKey {functionkey}
#>


param (

    # The lab's target machine resource ID
    [Parameter(Mandatory = $true)]
    [string] $LabMachineIpOrFqdn,

    # Port on which to reach the lab vm.  By default port is 3389.  If using the SharedIP feature, then the port will be different. 
    [Parameter(Mandatory = $false)]
    [int] $MachinePort = 3389,

    # The RD gateway hostname
    [Parameter(Mandatory = $true)]
    [string] $GatewayHostname,

    # Function key for function that creates authentication token
    [Parameter(Mandatory = $true)]
    [string] $FunctionKey
)

$tokenServiceBaseUrl = "http://$GatewayHostname/api"

$tokenServiceFullUrl = "$tokenServiceBaseUrl/host/$LabMachineIpOrFqdn/port/$MachinePort" 

$headers = @{
    "x-ms-client-object-id" = (Get-AzureRmADUser -UserPrincipalName ((Get-AzureRmContext).Account.Id)).Id
    "x-functions-key" = $FunctionKey
}

Write-Output "Connecting token service: $tokenServiceFullUrl "
$headers | FT

$response = Invoke-RestMethod -Uri $tokenServiceFullUrl -Headers $headers

if ($response -and $response.token) {

    $tokenHost = (($response.token -split "&")[0] -split "=")[1]
    $tokenPort = (($response.token -split "&")[1] -split "=")[1]

    $rdpFilePath = Join-Path $PSScriptRoot "$tokenHost.rdp"

    @(
        "full address:s:${tokenHost}:${tokenPort}",
        "prompt for credentials:i:1",
        "bandwidthautodetect:i:0"
        "gatewayhostname:s:$GatewayHostname",
        "gatewayaccesstoken:s:$($response.token)",
        "gatewayusagemethod:i:1",
        "gatewaycredentialssource:i:5",
        "gatewayprofileusagemethod:i:1"

    ) | Out-File -FilePath $rdpFilePath -Force

    Write-Output "Created RDP file at $rdpFilePath"

    Write-Output "Opening $rdpFilePath using mstsc.exe"
    Start-Process "mstsc.exe" -ArgumentList @( $rdpFilePath )
    
} else {

    Write-Error "Failed to get token from gateway API."
}