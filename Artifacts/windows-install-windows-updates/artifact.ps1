###################################################################################################

#
# PowerShell configurations
#

# NOTE: Because the $ErrorActionPreference is "Stop", this script will stop on first failure.
#       This is necessary to ensure we capture errors inside the try-catch-finally block.
$ErrorActionPreference = "Stop"

# Ensure we set the working directory to that of the script.
Push-Location $PSScriptRoot

###################################################################################################

trap
{
    # NOTE: This trap will handle all errors. There should be no need to use a catch below in this
    #       script, unless you want to ignore a specific error.
    $message = $Error[0].Exception.Message
    if ($message)
    {
        Write-Host -Object "`nERROR: $message" -ForegroundColor Red
    }

    Write-Host "`nThe artifact failed to apply.`n"

    # IMPORTANT NOTE: Throwing a terminating error (using $ErrorActionPreference = "Stop") still
    # returns exit code zero from the PowerShell script when using -File. The workaround is to
    # NOT use -File when calling this script and leverage the try-catch-finally block and return
    # a non-zero exit code from the catch block.
    exit -1
}

###################################################################################################

function Test-PowerShellVersion
{
    [CmdletBinding()]
    param(
        [double] $Version
    )

    $currentVersion = [double] "$($PSVersionTable.PSVersion.Major).$($PSVersionTable.PSVersion.Minor)"
    if ($currentVersion -lt $Version)
    {
        throw "The current version of PowerShell is $currentVersion. Prior to running this artifact, ensure you have PowerShell version $Version or higher installed."
    }
}

###################################################################################################

#
# Main execution block.
#

try
{
    Write-Host 'Validating local version of Powershell is higher than required for PSwindowsUpdate module.'
    Test-PowerShellVersion -Version 3.0

    Write-Host "Updating NuGet provider to a version higher than 2.8.5.201."
    Install-PackageProvider -Name NuGet -MinimumVersion 2.8.5.201 -Force | Out-Null

    Write-Host "Installing Powershell module 'PSWindowsUpdate'"
    Install-Module -Name PSWindowsUpdate -MinimumVersion 2.2.0.2 -Force | Out-Null
    Import-Module PSWindowsUpdate
    
    Write-Output 'Installing Windows Updates.'
    Get-WUInstall -IgnoreReboot -AcceptAll
    
    Write-Output "Windows Update finished. Rebooting..."
    Write-Host "`nThe artifact was applied successfully.`n"

    # Forcing the restart in script, as the artifact’s postDeployActions may timeout prematurely, prior to the Windows Updates completing, causing undesirable side effects.
    Restart-Computer -Force
}
finally
{
    Pop-Location
}
