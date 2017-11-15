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
    Handle-LastError
}

###################################################################################################

#
# Main execution block.
#

try
{
    #arguments passed to this script should be passed to the artifact script
    $command = $Script:MyInvocation.MyCommand
    $scriptName = $Script:MyInvocation.MyCommand.Name
    $scriptLine = $MyInvocation.Line
    $scriptArgIndex = $scriptLine.IndexOf($scriptName) + $scriptName.Length + 1
    if($scriptLine.Length -gt $scriptArgIndex)
    {
        $scriptArgs = $scriptLine.Substring($scriptArgIndex)
    }

    iex ".\artifact.ps1 $scriptArgs"

    Write-Host 'Artifact installed successfully.'
}
finally
{
    popd
}
