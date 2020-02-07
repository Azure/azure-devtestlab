##################################################################################################
#
# Parameters to this script file.
#

[CmdletBinding()]
param(
    # Space-, comma- or semicolon-separated list of Chocolatey packages.
    [string] $Packages,

    # Boolean indicating if we should allow empty checksums. Default to true to match previous artifact functionality despite security
    [bool] $AllowEmptyChecksums = $true,

    # Boolean indicating if we should ignore checksums. Default to false for security
    [bool] $IgnoreChecksums = $false,
    
    # Minimum PowerShell version required to execute this script.
    [int] $PSVersionRequired = 3
)

###################################################################################################
#
# PowerShell configurations
#

# NOTE: Because the $ErrorActionPreference is "Stop", this script will stop on first failure.
#       This is necessary to ensure we capture errors inside the try-catch-finally block.
$ErrorActionPreference = 'Stop'

# Suppress progress bar output.
$ProgressPreference = 'SilentlyContinue'

# Ensure we force use of TLS 1.2 for all downloads.
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12

# Expected path of the choco.exe file.
$choco = "$Env:ProgramData/chocolatey/choco.exe"

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

function Ensure-Chocolatey
{
    [CmdletBinding()]
    param(
        [string] $ChocoExePath
    )

    if (-not (Test-Path "$ChocoExePath"))
    {
        Set-ExecutionPolicy Bypass -Scope Process -Force; iex ((New-Object System.Net.WebClient).DownloadString('https://chocolatey.org/install.ps1'))
        if ($LastExitCode -eq 3010)
        {
            Write-Host 'The recent changes indicate a reboot is necessary. Please reboot at your earliest convenience.'
        }
    }
}

function Ensure-PowerShell
{
    [CmdletBinding()]
    param(
        [int] $Version
    )

    if ($PSVersionTable.PSVersion.Major -lt $Version)
    {
        throw "The current version of PowerShell is $($PSVersionTable.PSVersion.Major). Prior to running this artifact, ensure you have PowerShell $Version or higher installed."
    }
}

function Install-Packages
{
    [CmdletBinding()]
    param(
        [string] $ChocoExePath,
        $Packages
    )

    $Packages = $Packages.split(',; ', [StringSplitOptions]::RemoveEmptyEntries)
    $Packages | % {
        $checkSumFlags = ""
        if ($AllowEmptyChecksums)
        {
            $checkSumFlags = $checkSumFlags + " --allow-empty-checksums "
        }
        if ($IgnoreChecksums)
        {
            $checkSumFlags = $checkSumFlags + " --ignore-checksums "
        }
        $expression = "$ChocoExePath install -y -f --acceptlicense $checkSumFlags --no-progress --stoponfirstfailure $_"
        Invoke-ExpressionImpl -Expression $expression
    }
}

function Invoke-ExpressionImpl
{
    [CmdletBinding()]
    param(
        $Expression
    )

    # This call will normally not throw. So, when setting -ErrorVariable it causes it to throw.
    # The variable $expError contains whatever is sent to stderr.
    iex $Expression -ErrorVariable expError

    # This check allows us to capture cases where the command we execute exits with an error code.
    # In that case, we do want to throw an exception with whatever is in stderr. Normally, when
    # Invoke-Expression throws, the error will come the normal way (i.e. $Error) and pass via the
    # catch below.
    if ($LastExitCode -or $expError)
    {
        if ($LastExitCode -eq 3010)
        {
            # Expected condition. The recent changes indicate a reboot is necessary. Please reboot at your earliest convenience.
        }
        elseif ($expError[0])
        {
            throw $expError[0]
        }
        else
        {
            throw "Installation failed ($LastExitCode). Please see the Chocolatey logs in %ALLUSERSPROFILE%\chocolatey\logs folder for details."
        }
    }
}

function Validate-Params
{
    [CmdletBinding()]
    param(
    )

    if ([string]::IsNullOrEmpty($Packages))
    {
        throw 'Packages parameter is required.'
    }
}

###################################################################################################
#
# Main execution block.
#

try
{
    pushd $PSScriptRoot

    Write-Host 'Validating parameters.'
    Validate-Params

    Write-Host 'Configuring PowerShell session.'
    Ensure-PowerShell -Version $PSVersionRequired
    Enable-PSRemoting -Force -SkipNetworkProfileCheck | Out-Null

    Write-Host 'Ensuring latest Chocolatey version is installed.'
    Ensure-Chocolatey -ChocoExePath "$choco"

    Write-Host "Preparing to install Chocolatey packages: $Packages."
    Install-Packages -ChocoExePath "$choco" -Packages $Packages

    Write-Host "`nThe artifact was applied successfully.`n"
}
finally
{
    popd
}
