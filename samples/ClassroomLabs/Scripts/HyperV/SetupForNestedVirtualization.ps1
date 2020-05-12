<#
The MIT License (MIT)
Copyright (c) Microsoft Corporation  
Permission is hereby granted, free of charge, to any person obtaining a copy of this software and associated documentation files (the "Software"), to deal in the Software without restriction, including without limitation the rights to use, copy, modify, merge, publish, distribute, sublicense, and/or sell copies of the Software, and to permit persons to whom the Software is furnished to do so, subject to the following conditions:
The above copyright notice and this permission notice shall be included in all copies or substantial portions of the Software.  
THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE. 
.SYNOPSIS
This script prepares a Windows Server machine to use virtualization.  This includes enabling Hyper-V, enabling DHCP and setting up a switch to allow client virtual machines to have internet access.
#>

[CmdletBinding()]
param(
)

###################################################################################################
#
# PowerShell configurations
#

# NOTE: Because the $ErrorActionPreference is "Stop", this script will stop on first failure.
#       This is necessary to ensure we capture errors inside the try-catch-finally block.
$ErrorActionPreference = "Stop"

# Hide any progress bars, due to downloads and installs of remote components.
$ProgressPreference = "SilentlyContinue"

# Ensure we set the working directory to that of the script.
Push-Location $PSScriptRoot

# Discard any collected errors from a previous execution.
$Error.Clear()

# Configure strict debugging.
Set-PSDebug -Strict

###################################################################################################
#
# Handle all errors in this script.
#

trap {
    # NOTE: This trap will handle all errors. There should be no need to use a catch below in this
    #       script, unless you want to ignore a specific error.
    $message = $Error[0].Exception.Message
    if ($message) {
        Write-Host -Object "`nERROR: $message" -ForegroundColor Red
    }

    Write-Host "`nThe script failed to run.`n"

    # IMPORTANT NOTE: Throwing a terminating error (using $ErrorActionPreference = "Stop") still
    # returns exit code zero from the PowerShell script when using -File. The workaround is to
    # NOT use -File when calling this script and leverage the try-catch-finally block and return
    # a non-zero exit code from the catch block.
    exit -1
}

###################################################################################################
#
# Functions used in this script.
#             

<#
.SYNOPSIS
Returns true is script is running with administrator privileges and false otherwise.
#>
function Get-RunningAsAdministrator {
    [CmdletBinding()]
    param()
    
    $isAdministrator = ([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole] "Administrator")
    Write-Verbose "Running with Administrator privileges (t/f): $isAdministrator"
    return $isAdministrator
}

<#
.SYNOPSIS
Returns true is current machine is a Windows Server machine and false otherwise.
#>
function Get-RunningServerOperatingSystem {
    [CmdletBinding()]
    param()

    return ($null -ne $(Get-Module -ListAvailable -Name 'servermanager') )
}

<#
.SYNOPSIS
Enables Hyper-V role, including PowerShell cmdlets for Hyper-V and management tools.
#>
function Install-HypervAndTools {
    [CmdletBinding()]
    param()

    if (Get-RunningServerOperatingSystem) {
        Install-HypervAndToolsServer
    } else
    {
        Install-HypervAndToolsClient
    }
}

<#
.SYNOPSIS
Enables Hyper-V role for server, including PowerShell cmdlets for Hyper-V and management tools.
#>
function Install-HypervAndToolsServer {
    [CmdletBinding()]
    param()

    
    if ($null -eq $(Get-WindowsFeature -Name 'Hyper-V')) {
        Write-Error "This script only applies to machines that can run Hyper-V."
    }
    else {
        $roleInstallStatus = Install-WindowsFeature -Name Hyper-V -IncludeManagementTools
        if ($roleInstallStatus.RestartNeeded -eq 'Yes') {
            Write-Error "Restart required to finish installing the Hyper-V role .  Please restart and re-run this script."
        }  
    } 

    # Install PowerShell cmdlets
    $featureStatus = Enable-WindowsOptionalFeature -Online -FeatureName Microsoft-Hyper-V-Management-PowerShell
    if ($featureStatus.RestartNeeded -eq $true) {
        Write-Error "Restart required to finish installing the Hyper-V PowerShell Module.  Please restart and re-run this script."
    }
}

<#
.SYNOPSIS
Enables Hyper-V role for client (Win10), including PowerShell cmdlets for Hyper-V and management tools.
#>
function Install-HypervAndToolsClient {
    [CmdletBinding()]
    param()

    
    if ($null -eq $(Get-WindowsOptionalFeature -Online -FeatureName 'Microsoft-Hyper-V-All')) {
        Write-Error "This script only applies to machines that can run Hyper-V."
    }
    else {
        $roleInstallStatus = Enable-WindowsOptionalFeature -Online -FeatureName 'Microsoft-Hyper-V-All'
        if ($roleInstallStatus.RestartNeeded) {
            Write-Error "Restart required to finish installing the Hyper-V role .  Please restart and re-run this script."
        }

        $featureEnableStatus = Get-WmiObject -Class Win32_OptionalFeature -Filter "name='Microsoft-Hyper-V-Hypervisor'"
        if ($featureEnableStatus.InstallState -ne 1) {
            Write-Error "This script only applies to machines that can run Hyper-V."
            goto(finally)
        }

    } 
}

<#
.SYNOPSIS
Enables DHCP role, including management tools.
#>
function Install-DHCP {
    [CmdletBinding()]
    param()
   
    if ($null -eq $(Get-WindowsFeature -Name 'DHCP')) {
        Write-Error "This script only applies to machines that can run DHCP."
    }
    else {
        $roleInstallStatus = Install-WindowsFeature -Name DHCP -IncludeManagementTools
        if ($roleInstallStatus.RestartNeeded -eq 'Yes') {
            Write-Error "Restart required to finish installing the DHCP role .  Please restart and re-run this script."
        }  
    } 

    # Tell Windows we are done installing DHCP
    Set-ItemProperty -Path registry::HKEY_LOCAL_MACHINE\SOFTWARE\Microsoft\ServerManager\Roles\12 -Name ConfigurationState -Value 2
}

<#
.SYNOPSIS
Funtion will find object in given list with specified property of the specified expected value.  If object cannot be found, a new one is created by executing scropt in the NewObjectScriptBlock parameter.
.PARAMETER PropertyName
Property to check with looking for object.
.PARAMETER ExpectedPropertyValue
Expected value of property being checked.
.PARAMETER List
List of objects in which to look.
.PARAMETER NewObjectScriptBlock
Script to run if object with the specified value of specified property name is not found.

#>
function Select-ResourceByProperty {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)][string]$PropertyName ,
        [Parameter(Mandatory = $true)][string]$ExpectedPropertyValue,
        [Parameter(Mandatory = $false)][array]$List = @(),
        [Parameter(Mandatory = $true)][scriptblock]$NewObjectScriptBlock
    )
    
    $returnValue = $null
    $items = @($List | Where-Object $PropertyName -Like $ExpectedPropertyValue)
    
    if ($items.Count -eq 0) {
        Write-Verbose "Creating new item with $PropertyName =  $ExpectedPropertyValue."
        $returnValue = & $NewObjectScriptBlock
    }
    elseif ($items.Count -eq 1) {
        $returnValue = $items[0]
    }
    else {
        $choice = -1
        $choiceTable = New-Object System.Data.DataTable
        $choiceTable.Columns.Add($(new-object System.Data.DataColumn("Option Number")))
        $choiceTable.Columns[0].AutoIncrement = $true
        $choiceTable.Columns[0].ReadOnly = $true
        $choiceTable.Columns.Add($(New-Object System.Data.DataColumn($PropertyName)))
        $choiceTable.Columns.Add($(New-Object System.Data.DataColumn("Details")))
           
        $choiceTable.Rows.Add($null, "\< Exit \>", "Choose this option to exit the script.") | Out-Null
        $items | ForEach-Object { $choiceTable.Rows.Add($null, $($_ | Select-Object -ExpandProperty $PropertyName), $_.ToString()) } | Out-Null

        Write-Host "Found multiple items with $PropertyName = $ExpectedPropertyValue.  Please choose on of the following options."
        $choiceTable | ForEach-Object { Write-Host "$($_[0]): $($_[1]) ($($_[2]))" }

        while (-not (($choice -ge 0 ) -and ($choice -le $choiceTable.Rows.Count - 1 ))) {     
            $choice = Read-Host "Please enter option number. (Between 0 and $($choiceTable.Rows.Count - 1))"           
        }
    
        if ($choice -eq 0) {
            Write-Error "User cancelled script."
        }
        else {
            $returnValue = $items[$($choice - 1)]
        }
          
    }

    return $returnValue
}

###################################################################################################
#
# Main execution block.
#

try {

    # Check that script is being run with Administrator privilege.
    Write-Output "Verify running as administrator."
    if (-not (Get-RunningAsAdministrator)) { Write-Error "Please re-run this script as Administrator." }

    # Install HyperV service and client tools
    Write-Output "Installing Hyper-V, if needed."
    Install-HypervAndTools

    # Pin Hyper-V to the user's desktop.
    Write-Output "Creating shortcut to Hyper-V Manager on desktop."
    $Shortcut = (New-Object -ComObject WScript.Shell).CreateShortcut($(Join-Path "$env:UserProfile\Desktop" "Hyper-V Manager.lnk"))
    $Shortcut.TargetPath = "$env:SystemRoot\System32\virtmgmt.msc"
    $Shortcut.Save()

    # Ip addresses and range information.
    $ipAddress = "192.168.0.1"
    $ipAddressPrefixRange = "24"
    $ipAddressPrefix = "192.168.0.0/$ipAddressPrefixRange"
    $startRangeForClientIps = "192.168.0.100"
    $endRangeForClientIps = "192.168.0.200"
    $subnetMaskForClientIps = "255.255.255.0"
    # Azure Static DNS Server IP
    $dnsServerIp = "168.63.129.16"

    if (Get-RunningServerOperatingSystem) {
        # Install DHCP so client vms will automatically get an IP address.
        Write-Output "Installing DHCP, if needed."
        Install-DHCP 

        # Add scope for client vm ip address
        $scopeName = "LabServicesDhcpScope"

        $dhcpScope = Select-ResourceByProperty `
            -PropertyName 'Name' -ExpectedPropertyValue $scopeName `
            -List @(Get-DhcpServerV4Scope) `
            -NewObjectScriptBlock { Add-DhcpServerv4Scope -name $scopeName -StartRange $startRangeForClientIps -EndRange $endRangeForClientIps -SubnetMask $subnetMaskForClientIps -State Active
                                    Set-DhcpServerV4OptionValue -DnsServer $dnsServerIp -Router $ipAddress
                                }
        Write-Output "Using $dhcpScope"
    

        # Create Switch
        Write-Output "Setting up network for client virtual machines."
        $switchName = "LabServicesSwitch"
        $vmSwitch = Select-ResourceByProperty `
            -PropertyName 'Name' -ExpectedPropertyValue $switchName `
            -List (Get-VMSwitch -SwitchType Internal) `
            -NewObjectScriptBlock { New-VMSwitch -Name $switchName -SwitchType Internal }
        Write-Output "Using $vmSwitch"

        # Get network adapter information
        $netAdapter = Select-ResourceByProperty `
            -PropertyName "Name" -ExpectedPropertyValue "*$switchName*"  `
            -List @(Get-NetAdapter) `
            -NewObjectScriptBlock { Write-Error "No Net Adapters found" } 
        Write-Output "Using  $netAdapter"
        Write-Output "Adapter found is $($netAdapter.ifAlias) and Interface Index is $($netAdapter.ifIndex)"

        # Create IP Address 
        $netIpAddr = Select-ResourceByProperty  `
            -PropertyName 'IPAddress' -ExpectedPropertyValue $ipAddress `
            -List @(Get-NetIPAddress) `
            -NewObjectScriptBlock { New-NetIPAddress -IPAddress $ipAddress -PrefixLength $ipAddressPrefixRange -InterfaceIndex $netAdapter.ifIndex }
        if (($netIpAddr.PrefixLength -ne $ipAddressPrefixRange) -or ($netIpAddr.InterfaceIndex -ne $netAdapter.ifIndex)) {
            Write-Error "Found Net IP Address $netIpAddr, but prefix $ipAddressPrefix ifIndex not $($netAdapter.ifIndex)."
        }
        Write-Output "Net ip address found is $ipAddress"

        # Create NAT
        $natName = "LabServicesNat"
        $netNat = Select-ResourceByProperty -PropertyName 'Name' -ExpectedPropertyValue $natName -List @(Get-NetNat) -NewObjectScriptBlock { New-NetNat -Name $natName -InternalIPInterfaceAddressPrefix $ipAddressPrefix }
        if ($netNat.InternalIPInterfaceAddressPrefix -ne $ipAddressPrefix) {
            Write-Error "Found nat with name $natName, but InternalIPInterfaceAddressPrefix is not $ipAddressPrefix."
        }
        Write-Output "Nat found is $netNat"
        #Make sure WinNat will start automatically so Hyper-V VMs will have internet connectivity.
        Set-Service -Name WinNat -StartupType Automatic
        if ($(Get-Service -Name WinNat | Select-Object -ExpandProperty StartType) -ne 'Automatic')
        {
            Write-Host "Unable to set WinNat service to Automatic.  Hyper-V virtual machines will not have internet connectivity when service is not running." -ForegroundColor Yellow
        }  
    }
    else {
        Write-Host -Object "DHCP Server is not supported on Windows 10. `
        Use 'Default Switch' for the Configure Networking connection." -ForegroundColor Yellow
    }
    # Tell the user script is done.    
    Write-Host -Object "Script completed." -ForegroundColor Green
}
finally {
    # Restore system to state prior to execution of this script.
    Pop-Location
}