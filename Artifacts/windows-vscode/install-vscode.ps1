###################################################################################################
#
# PowerShell configurations
#

# NOTE: Because the $ErrorActionPreference is "Stop", this script will stop on first failure.
#       This is necessary to ensure we capture errors inside the try-catch-finally block.
$ErrorActionPreference = "Stop"

# Hide any progress bars, due to downloads and installs of remote components.
$ProgressPreference = "SilentlyContinue"

# Discard any collected errors from a previous execution.
$Error.Clear()

# Allow certian operations, like downloading files, to execute.
Set-ExecutionPolicy Bypass -Scope Process -Force

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

Function Get-RedirectedUrl
{
    [CmdletBinding()]
    Param (
        [String]$URL
    )
 
    $request = [System.Net.WebRequest]::Create($url)
    $request.AllowAutoRedirect=$false
    $response=$request.GetResponse()
 
    If ($response.StatusCode -eq "Found")
    {
        return $response.GetResponseHeader("Location")
    }
}

function Get-VSCodeSetup
{
    [CmdletBinding()]
    param(
        [string] $SetupExe
    )

    $fwdUrl = 'http://go.microsoft.com/fwlink/?LinkID=623230'
    $setupUrl = Get-RedirectedUrl -URL $fwdUrl

    [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
    Invoke-WebRequest -Uri $setupUrl -OutFile $SetupExe
}

###################################################################################################
#
# Main execution block.
#

Write-Host "Preparing to install the latest Visual Studio Code."
$setupExe = Join-Path $PSScriptRoot 'vscodesetup.exe'
$setupLog = Join-Path $PSScriptRoot 'vscodesetup.log'
$setupInf = Join-Path $PSScriptRoot 'vscode.inf'

try
{
    Push-Location $PSScriptRoot

    Write-Host "Downloading the Visual Studio Setup installer."
    Get-VSCodeSetup -SetupExe "$setupExe"

    Write-Host "Installing Visual Studio Code."
    & "$setupExe" /123 /SP- /SUPPRESSMSGBOXES /VERYSILENT /NORESTART /LOG="$setupLog" /LOADINF="$setupInf" /MERGETASKS="!runcode"

    Write-Host "`nThe artifact was applied successfully.`n"
}
finally
{
    Pop-Location
}