[CmdletBinding()]
param(
    [ValidateSet("32-bit","64-bit")] 
    [string] $Architecture = '64-bit',
    [switch] $DesktopIcon
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


function Get-VSCodeSetup
{
    [CmdletBinding()]
    param(
        [string] $SetupExe,
        [ValidateSet("32-bit","64-bit")] 
        [string] $Architecture
    )

    $url=''

    switch ($Architecture)
    {
        '32-bit' { $url = 'https://update.code.visualstudio.com/latest/win32/stable' }
        '64-bit' { $url = 'https://update.code.visualstudio.com/latest/win32-x64/stable' }
    }


    Invoke-WebRequest -Uri $url -OutFile $SetupExe -UseBasicParsing
}

###################################################################################################
#
# Main execution block.
#

Write-Host "Preparing to install the latest version of Visual Studio Code ($Architecture)."
$setupExe = Join-Path $PSScriptRoot 'vscodesetup.exe'
$setupLog = Join-Path $PSScriptRoot 'vscodesetup.log'
$setupExe = Join-Path $env:temp 'vscodesetup.exe'
$setupLog = Join-Path $env:temp 'vscodesetup.log'

try
{
    Push-Location $PSScriptRoot

    Write-Host "Downloading Visual Studio Code ($Architecture) installer."
    Get-VSCodeSetup -SetupExe  $SetupExe -Architecture $Architecture
    

    # Switches documentation: (https://jrsoftware.org/ishelp/)
    # /SP-: Disables the 'This will install VS Code. Do you wish to continue?' prompt 
    #       at the beginning of Setup.
    # /SUPPRESSMSGBOXES: Suppress message boxes, use defaults. (Folder location, 
    #                    language, tasks, etc.)
    # /VERYSILENT: Progress window is not displayed.
    # /NORESTART: Prevents Setup from restarting the system, after a successful installation
    # /LOG: Creates a log file
    # /MERGETASKS: Specifies a comma-separated list of tasks and merges it with the default

    #     Here is the full list of tasks available in VSCode (*=default):
    #     desktopicon -- Creates a desktop icon
    #     quicklaunchicon -- Creates a quick launch shortcut (Windows XP only)
    #     addcontextmenufiles -- Right click open menu for files in explorer.exe
    #     addcontextmenufolders -- Right click open menu for folders in explorer.exe
    #     *associatewithfiles -- Associates hundreds of file extensions to VsCode.exe
    #     *addtopath -- Adds the vscode folder in the path environment variable
    #     *runcode -- Runs the vscode after interactive setup. Ignored when install is silent
    
    $desk = if ($DesktopIcon) {'desktopicon,'} else {''};
    $tasks= $desk + "addcontextmenufiles,addcontextmenufolders";

    Write-Host "Installing Visual Studio Code ($Architecture)."
    & "$setupExe" /SP- /SUPPRESSMSGBOXES /VERYSILENT /NORESTART /LOG="$setupLog" /MERGETASKS="$tasks" | Out-Default

    Write-Host "`nThe artifact was applied successfully.`n"
}
finally
{
    Pop-Location
}