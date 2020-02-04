[CmdletBinding()]
param(
    [ValidateSet("32-bit","64-bit")] 
    [string] $Architecture = '32-bit'
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

# Ensure we force use of TLS 1.2 for all downloads.
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12

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
        [String]$Url
    )
 
    $request = [System.Net.WebRequest]::Create($Url)
    $request.AllowAutoRedirect = $false
    $response = $request.GetResponse()
 
    If ($response.StatusCode -eq 'Found')
    {
        return $response.GetResponseHeader('Location')
    }

    return $Url
}

function Get-VSCodeSetup
{
    [CmdletBinding()]
    param(
        [string] $SetupExe,

        [ValidateSet("32-bit","64-bit")] 
        [string] $Architecture
    )

    switch ($Architecture)
    {
        '32-bit' { $url = 'http://go.microsoft.com/fwlink/?LinkID=623230' }
        '64-bit' { $url = 'https://update.code.visualstudio.com/latest/win32-x64-user/stable' }
    }

    $setupUrl = Get-RedirectedUrl -URL $url

    Invoke-WebRequest -Uri $setupUrl -OutFile $SetupExe
}

###################################################################################################
#
# Main execution block.
#

Write-Host "Preparing to install the latest version of Visual Studio Code ($Architecture)."
$setupExe = Join-Path $PSScriptRoot 'vscodesetup.exe'
$setupLog = Join-Path $PSScriptRoot 'vscodesetup.log'
$setupInf = Join-Path $PSScriptRoot 'vscode.inf'

try
{
    Push-Location $PSScriptRoot

    Write-Host "Downloading Visual Studio Code ($Architecture) installer."
    Get-VSCodeSetup -SetupExe "$setupExe" -Architecture "$Architecture"

    Write-Host "Installing Visual Studio Code ($Architecture)."
    & "$setupExe" /123 /SP- /SUPPRESSMSGBOXES /VERYSILENT /NORESTART /LOG="$setupLog" /LOADINF="$setupInf" /MERGETASKS="!runcode"

    Write-Host "`nThe artifact was applied successfully.`n"
}
finally
{
    Pop-Location
}