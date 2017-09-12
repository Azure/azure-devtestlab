[CmdletBinding()]
param(
    [string] $StringParam,
    [securestring] $SecureStringParam,
    [int] $IntParam,
    [switch] $BoolParam,
    [string] $ArrayParam,
    [string] $ObjectParam,
    [int] $ExtraLogLines,
    [switch] $ForceFail
)

###################################################################################################

#
# PowerShell configurations
#

# NOTE: Because the $ErrorActionPreference is "Stop", this script will stop on first failure.
#       This is necessary to ensure we capture errors inside the try-catch-finally block.
$ErrorActionPreference = "Stop"

# Ensure we set the working directory to that of the script.
pushd $PSScriptRoot

###################################################################################################

#
# Functions used in this script.
#

function Handle-LastError
{
    [CmdletBinding()]
    param(
    )

    $message = $error[0].Exception.Message
    if ($message)
    {
        Write-Host -Object "ERROR: $message" -ForegroundColor Red
    }
    
    # IMPORTANT NOTE: Throwing a terminating error (using $ErrorActionPreference = "Stop") still
    # returns exit code zero from the PowerShell script when using -File. The workaround is to
    # NOT use -File when calling this script and leverage the try-catch-finally block and return
    # a non-zero exit code from the catch block.
    exit -1
}

###################################################################################################

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
    Write-Output 'Processing parameters:'
    Write-Output "  string: $StringParam"
    Write-Output "  securestring: '********'"
    Write-Output "  int: $IntParam"
    Write-Output "  bool: $BoolParam"
    Write-Output "  array: $(ConvertFrom-Json $ArrayParam)"
    Write-Output "  object: $(ConvertFrom-Json $ObjectParam)"

    if ($ExtraLogLines -gt 0)
    {
        Write-Output 'Dumping extra log lines:'
        1..$ExtraLogLines | % {
            Write-Output "  INFO: Sample log line #$_"
        }
    }

    if ($ForceFail)
    {
        throw 'Forcing artifact to fail.'
    }
}
finally
{
    popd
}
