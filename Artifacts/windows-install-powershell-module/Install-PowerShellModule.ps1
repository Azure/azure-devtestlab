<#
  Installs the specified PowerShell module using PowerShellGallery.
#>
[CmdletBinding()]
param(
    [ValidateNotNullOrEmpty()]
    [string] $moduleName
)

##################################################################################################
#
# Powershell Configurations
#

# Note: Because the $ErrorActionPreference is "Stop", this script will stop on first failure.  
#       This is necessary to ensure we capture errors inside the try-catch-finally block.
$ErrorActionPreference = "Stop"

# Ensure we set the working directory to that of the script.
Push-Location $PSScriptRoot

###################################################################################################
#
# Handle all errors in this script.
#

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
#
# Functions used in this script.
#

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
    Write-Host "Starting installation of requested module $moduleName."

    Write-Host 'Configuring PowerShell session.'
    Test-PowerShellVersion -Version 5.1
    
    Write-Host "Updating NuGet provider to a version higher than 2.8.5.201."
    Install-PackageProvider -Name NuGet -MinimumVersion 2.8.5.201 -Force | Out-Null

    Write-Host "Installing module $moduleName."
    Install-Module -Name $moduleName -AllowClobber -Force

    Write-Host "Importing module $moduleName to validate correct installation."
    Import-Module $moduleName

    Write-Host "`nThe artifact was applied successfully.`n"
}
finally
{
    Pop-Location
}
