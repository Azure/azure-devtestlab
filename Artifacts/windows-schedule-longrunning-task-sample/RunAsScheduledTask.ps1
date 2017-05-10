try
{
    $ErrorActionPreference ='Stop'

    $scriptName = "SampleLongPing.ps1"
    
    Write-Host "Installing TaskRunner module from powershell gallery"
    Install-Module TaskRunner -force

    # Validate script
    $vsInstallScript = "$PSScriptRoot\$scriptName"
    if (-not (Test-Path $vsInstallScript))
    {
        Write-Error "Script does not exist : $psScriptRoot\$scriptName"
    }

    # Start Scheduled Task
    $taskOutput = RunTask -coreScriptFilePath $vsInstallScript -arguments "$edition" -waitForCompletion $true -timeoutInMins 80 -cleanup $false
    Write-Host "Task output : $taskOutput"
    $exitCode = $taskOutput[$taskOutput.Count - 1]
    Write-Host "Task exited with exit code: $exitCode"

    # Check for timeout expired
    if ($exitCode -eq -10)
    {
        Write-Host ("Task still didnt complete. Next artifact needs to be added to watch the installation proceed through.")
        exit 0
    }

    exit $exitCode
}
catch
{
    Write-Host "Exception hit : $_.Message"
    exit -1
}
