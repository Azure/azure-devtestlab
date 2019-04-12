###################################################################################################
#
# PowerShell configurations
#

# NOTE: Because the $ErrorActionPreference is "Stop", this script will stop on first failure.
#       This is necessary to ensure we capture all errors inside the try-finally block.
$ErrorActionPreference = 'Stop'

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
    $message = $error[0].Exception.Message
    if ($message)
    {
        Write-Host -Object "`nERROR: $message" -ForegroundColor Red
    }
    
    # IMPORTANT NOTE: Throwing a terminating error (using $ErrorActionPreference = "Stop") still
    # returns exit code zero from the PowerShell script when using -File. The workaround is to
    # NOT use -File when calling this script and leverage the try-finally block and return
    # a non-zero exit code from the trap.
    exit -1
}

###################################################################################################
#
# Main execution block.
#

try
{
    Write-Host "`nThis script is obsolete and will be removed in the future. Please use one of the following specific scripts:`n"
    Write-Host '  - Resource Manager: use CopyRmVHDFromVMToLab.ps1'
    Write-Host '  - Classic: use CopyClassicVHDFromVMToLab.ps1'
    throw 'ObsoleteScript - see note above for details.'
}
finally
{
    1..3 | ForEach-Object { [console]::beep(2500,300) } # Make a sound to indicate we're done.
    Pop-Location
}
