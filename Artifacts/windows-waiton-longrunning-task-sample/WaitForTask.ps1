try
{
    $ErrorActionPreference ='Stop'

    $taskOutput = WaitForTaskCompletion -timeoutInMins 80 -cleanup $false
    Write-Host "Task output : $taskOutput"
    $exitCode = $taskOutput
    
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