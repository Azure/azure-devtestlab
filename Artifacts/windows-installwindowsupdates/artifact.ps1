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

function Handle-LastError
{
    [CmdletBinding()]
    param(
    )

    $message = $error[0].Exception.Message
    if ($message)
    {
        Write-Host -Object "ERROR: $message" -ForegroundColor Red
        Write-Host -Object $error -ForegroundColor Red
    }
    
    # IMPORTANT NOTE: Throwing a terminating error (using $ErrorActionPreference = "Stop") still
    # returns exit code zero from the PowerShell script when using -File. The workaround is to
    # NOT use -File when calling this script and leverage the try-catch-finally block and return
    # a non-zero exit code from the catch block.
    exit -1
}

#
# Handle all errors in this script.
#
trap
{
    # NOTE: This trap will handle all errors. There should be no need to use a catch below in this
    #       script, unless you want to ignore a specific error.
    Handle-LastError
}

###################################################################################################

#
# Main execution block.
#

try
{
    Add-Type -AssemblyName System.IO.Compression.FileSystem

    $scriptFolder = Split-Path $Script:MyInvocation.MyCommand.Path
    $localZipFile = Join-Path $scriptFolder 'PSWindowsUpdate.zip'
    
    # PSWindowsUpdate module downloaded from here:  https://gallery.technet.microsoft.com/scriptcenter/2d191bcd-3308-4edd-9de2-88dff796b0bc
    [System.IO.Compression.ZipFile]::ExtractToDirectory($localZipFile, $scriptFolder)
    
    $modulePath = Join-Path $scriptFolder "PSWindowsUpdate\PSWindowsUpdate.psm1"
    Import-Module $modulePath
    
    Write-Output 'Installing the updates'
    Get-WUInstall -IgnoreReboot -AcceptAll
    
    Write-Output 'Installation finished. Restarting...'

    # Restart from the powershell script instead of a postdeploy action
    # This avoids restarting too early in case there are a lot of updates to install
    Restart-Computer -Force
}
finally
{
    Pop-Location
}
