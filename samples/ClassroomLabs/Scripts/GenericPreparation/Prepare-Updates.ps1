<#
.SYNOPSIS
This script installs updates for a Windows 10 machine and turns off automatic updates to avoid class disruption.  
#>

[CmdletBinding()]
param( )

###################################################################################################
#
# PowerShell configurations
#

# NOTE: Because the $ErrorActionPreference is "Stop", this script will stop on first failure.
$ErrorActionPreference = "Stop"

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

    Write-Host "`nThe script failed to run.`n" -ForegroundColor Red

    exit -1
}

###################################################################################################
#
# Functions
#             

<#
.SYNOPSIS
Returns true is script is running with administrator privileges and false otherwise.
#>
function Get-RunningAsAdministrator {
    [CmdletBinding()]
    param()
    
    $isAdministrator = ([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole] "Administrator")
    $null = @(
        Write-Verbose "Running with$(if(-not $isAdministrator) {"out"}) Administrator privileges."
    )
    return $isAdministrator
}

<#
.SYNOPSIS
Funtion will install a required updates.  User will be notified if restart is needed.
#>
function Install-OsUpdates {
    Write-Host "Installing tools needed to update the operation system."
    Install-PackageProvider -Name NuGet -MinimumVersion 2.8.5.201 -Force | Out-Null
    Install-Module PSWindowsUpdate -Force | Out-Null

    Write-Host "Installing required updates available from Microsoft Update."
    $updatesInfo = Get-WUInstall -MicrosoftUpdate -AcceptAll
    Write-Output $updatesInfo | Format-Table

    $updatesRequiringReboot = @($updatesInfo | where {$_.RebootRequired -eq $true})
    if ($updatesRequiringReboot.Count -gt 0)
    {
        Write-Host "Please restart the computer.  Reboot required for updates to be fully installed." -ForegroundColor Yellow
    }
 }

 <#
.SYNOPSIS
Turn of automatic updates for the operating system to avoid interruptions during class hours.
#>
function Stop-AutoOsUpdates{
    Write-Host "Turning off auto-update for operating system."
    New-Item -Path "HKLM:\SOFTWARE\Policies\Microsoft\Windows\AU" -Force | Out-Null
    New-ItemProperty -Path "HKLM:\SOFTWARE\Policies\Microsoft\Windows\AU" -Name "NoAutoUpdate" -Value "1" -PropertyType DWORD -Force | Out-Null
}


###################################################################################################
#
# Main execution block.
#
try {
    Write-Host "Verifying running as administrator."
    if (-not (Get-RunningAsAdministrator)) { 
        Write-Error "Please re-run this script as Administrator." 
    }

    Install-OsUpdates

    Stop-AutoOsUpdates

    Write-Host -Object "Script completed successfully." -ForegroundColor Green
}
finally {
    # Restore system to state prior to execution of this script.
    Pop-Location
}
