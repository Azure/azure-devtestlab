[CmdletBinding()]
param(
    [string] $StringParam,
    [securestring] $SecureStringParam,
    [int] $IntParam,
    [switch] $BoolParam,
    [string] $ArrayParam,
    [string] $ObjectParam,
    [string] $FileContentsParam,
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
# Handle all errors in this script.
#

trap
{
    # NOTE: This trap will handle all errors. There should be no need to use a catch below in this
    #       script, unless you want to ignore a specific error.
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
# Main execution block.
#

try
{
    Write-Host 'Processing parameters:'
    Write-Host "  string: $StringParam"
    Write-Host "  securestring: '********'"
    Write-Host "  int: $IntParam"
    Write-Host "  bool: $BoolParam"
    Write-Host "  array: $(ConvertFrom-Json $ArrayParam)"
    Write-Host "  object: $(ConvertFrom-Json $ObjectParam)"
    Write-Host "  filecontents: $FileContentsParam"

    if ($ExtraLogLines -gt 0)
    {
        Write-Host 'Dumping extra log lines:'
        1..$ExtraLogLines | % {
            Write-Host "  INFO: Sample log line #$_"
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