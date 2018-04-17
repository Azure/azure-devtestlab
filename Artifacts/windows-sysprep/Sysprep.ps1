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
    # Remove the registered task, as we don't want it to execute again.
    Unregister-ScheduledTask -TaskName 'Sysprep' -Confirm:$false | Out-Null

    # Clean up registry entries.
    $cleanRegistryBat = 'C:\Users\Public\CleanRegistry.bat'
    cmd /c $cleanRegistryBat
    Remove-Item -Force $cleanRegistryBat | Out-Null

    # Remove any left over CustomScriptExtension files.
    $cseDir = 'C:\Packages\Plugins\Microsoft.Compute.CustomScriptExtension\'
    if (Test-Path -Path $cseDir)
    {
        Remove-Item -Recurse -Force $cseDir | Out-Null
    }

    # Execute the Sysprep command.
    $newProcess = new-object System.Diagnostics.ProcessStartInfo "sysprep.exe" 
    $newProcess.WorkingDirectory = "${env:SystemDrive}\windows\system32\sysprep" 
    $newProcess.Arguments = "/generalize /oobe /shutdown" 
    $newProcess.Verb = "runas"
    [System.Diagnostics.Process]::Start($newProcess) | Out-Null
}
finally
{
    # Remove this script. PS will continue running since it loads a copy of the script.
    Remove-Item -Force 'C:\Users\Public\Sysprep.ps1' | Out-Null
    popd
}