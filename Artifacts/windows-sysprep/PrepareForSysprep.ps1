###################################################################################################
#
# PowerShell configurations
#

# NOTE: Because the $ErrorActionPreference is "Stop", this script will stop on first failure.
#       This is necessary to ensure we capture errors inside the try-catch-finally block.
$ErrorActionPreference = "Stop"

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
    # Ensure we set the working directory to that of the script.
    pushd $PSScriptRoot

    Write-Host 'Preparing virtual machine for sysprep.'
    Copy-Item -Path ".\Sysprep.ps1" -Destination 'C:\Users\Public\Sysprep.ps1' | Out-Null
    Copy-Item -Path ".\CleanRegistry.bat" -Destination 'C:\Users\Public\CleanRegistry.bat' | Out-Null

    Write-Host 'Scheduling sysprep task to execute after a system restart.'
    $taskname = 'Sysprep'
    $taskdescription = 'Sysprep System'
    $action = New-ScheduledTaskAction -Execute 'Powershell.exe' -Argument " -ExecutionPolicy ByPass -File C:\Users\Public\Sysprep.ps1"
    $trigger = New-ScheduledTaskTrigger -AtStartup
    $settings = New-ScheduledTaskSettingsSet -ExecutionTimeLimit (New-TimeSpan -Minutes 60) -RestartCount 3 -RestartInterval (New-TimeSpan -Minutes 1)
    Register-ScheduledTask -Action $action -Trigger $trigger -TaskName $taskname -Description $taskdescription -Settings $settings -User 'System' -RunLevel Highest | Out-Null

    Write-Host 'Sysprep is not complete until the virtual machine is in a stopped state.'
}
finally
{
    popd
}