Param
(
  [ValidateNotNullOrEmpty()][string] $filePath,
  [ValidateNotNullOrEmpty()][string] $username,
  [ValidateNotNullOrEmpty()][string] $password
)

$Logfile = [System.IO.Path]::Combine($PSScriptRoot, "ScheduledTaskLog" + ".txt")

Add-content $Logfile -value "FilePath : $filePath"
Add-content $Logfile -value "Username : $username"
Add-content $Logfile -value "Password : $password"

$psFilePath = [System.IO.Path]::Combine($PSScriptRoot, "Start_process_write_signal_file.ps1")
$fileName = [System.IO.Path]::GetFileNameWithoutExtension($filePath)
$signalFileNameWithoutExtension = $fileName + "" + [System.Guid]::NewGuid().ToString("N").Substring(0, 5).ToLower()
$signalFilePath = [System.IO.Path]::Combine($PSScriptRoot, $signalFileNameWithoutExtension + ".txt")
$taskName = $signalFileNameWithoutExtension

# Create a task trigger to run at user logon.
Add-content $Logfile -value "Creating a new scheduled task"
$taskTrigger = New-ScheduledTaskTrigger -AtLogOn

# Define a task action to run the companion script.
Add-content $Logfile -value "Creating a new scheduled task action"
$actionExecutable = "powershell"
$actionArgs = ("-ExecutionPolicy Bypass -NoProfile -File `"" + $psFilePath + "`" `"" + $filePath + "`" " +$signalFilePath)
$taskAction = New-ScheduledTaskAction -Execute $actionExecutable -Argument $actionArgs

# Create a new scheduled task
Add-content $Logfile -value "Registering scheduled task : $taskName"
$schtask = Register-ScheduledTask -TaskName $taskName -Trigger $taskTrigger -Action $taskAction -User "$env:COMPUTERNAME\$($username)" -Password $password -RunLevel Highest

Add-content $Logfile -value "Starting scheduled task"
Start-ScheduledTask -TaskName $taskName
Start-Sleep -s 10
Disable-ScheduledTask -TaskName $taskName

# Now wait for the exit signal file
$timeoutMinutes = 180
$exitCode = -1
$startTime = Get-Date

# default code, means timeout
$timeout = $false

while ($timeout -eq $false)
{
    Add-content $Logfile -value "Checking for signal file"
    if (Test-Path $signalFilePath)
    {
        $exitCode = Get-Content $signalFilePath | Out-String

        Add-content $Logfile -value "Signal received, exit code = $exitCode"
        break
    }

    Add-content $Logfile -value "Sleeping"
    Start-Sleep -s 30

    $now = Get-Date
    $timeout = (New-TimeSpan $startTime $now).TotalMinutes -gt $timeoutMinutes
}

# set action to null
Add-content $Logfile -value "Updating the scheduled task action"
$emptyTaskAction = New-ScheduledTaskAction -Execute $actionExecutable

Set-ScheduledTask -TaskName $taskName -Action $emptyTaskAction -User "$env:COMPUTERNAME\$($username)" -Password $password
Add-content $Logfile -value "Exiting with exit code : $exitCode"

exit $exitCode