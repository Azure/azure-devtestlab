<##################################################################################################

    Usage Example
    =============

    Import-Module <path to RunTask.psm1>
    RunTask -coreScriptFilePath "C:\Script\InstallProduct.ps1" -arguments "arg1 arg2"
    

    Help / Documentation
    ====================
    - To view a cmdlet's help description: Get-help "cmdlet-name" -Detailed
    - To view a cmdlet's usage example: Get-help "cmdlet-name" -Examples


    Pre-Requisites
    ==============
    - This module must run with Administrator privileges.


    Known Issues
    ============
    - 
##################################################################################################>

$shortTaskLocation = "${env:Systemdrive}\_TaskScripts_"
$taskNameFile = "$shortTaskLocation\taskName.txt"

function RunTask {

    <#
        .SYNOPSIS
        Creates a new scheduled task and waits for the task to complete, while dumping live logs continuously

        .DESCRIPTION
        Creates a new scheduled task and waits for the task to complete, while dumping live logs continuously

        .EXAMPLE
        RunTask -coreScriptFilePath "C:\Script\InstallProduct.ps1" -arguments "arg1 arg2"
        RunTask -coreScriptFilePath "C:\Script\InstallProduct.ps1" -arguments "arg1 arg2" -waitForCompletion $true -cleanup $true
        RunTask -coreScriptFilePath "C:\Script\InstallProduct.ps1" -arguments "arg1 arg2" -waitForCompletion $true -timeoutInMins 30 -cleanup $true

        .INPUTS
        None.
    #>
    Param (

        [Parameter(Mandatory=$true)]
        [string] $coreScriptFilePath,

        [string] $arguments,

        [bool] $waitForCompletion = $true,

        [string] $timeoutInMins = 80,

        [bool] $cleanup = $false
    )

    PROCESS
    {

        $ErrorActionPreference = 'Stop'

        try
        {
            Write-Host "ScriptName : $coreScriptFilePath"
            Write-Host "Arguments : $arguments"
            Write-Host "Wait for Completion : $waitForCompletion"
            Write-Host "Timeout : $timeoutInMins"

            # Create a shorter task directory
            New-Item $shortTaskLocation -Type Directory -Force | Out-Null
            Write-Host "Directory to be used for task : $shortTaskLocation"

            # Get Signal script path
            $getSignalScriptFilePath = [System.IO.Path]::Combine($PSScriptRoot, "StartProcess_GetSignal.ps1")

            # Copy the required scripts to task directory
            Copy-Item $getSignalScriptFilePath $shortTaskLocation -Force
            Copy-Item $coreScriptFilePath $shortTaskLocation -Force
            Write-Host "Copied scripts to a shorter task directory : $shortTaskLocation"

            # New file paths
            $newCoreScriptFilePath = [System.IO.Path]::Combine($shortTaskLocation, [System.IO.Path]::GetFileName($coreScriptFilePath))
            $newGetSignalScriptFilePath = [System.IO.Path]::Combine($shortTaskLocation, [System.IO.Path]::GetFileName($getSignalScriptFilePath))

            # Task Name
            $newId = (Get-Random -minimum 1 -maximum 101).ToString()
            $taskName = [System.IO.Path]::GetFileNameWithoutExtension($coreScriptFilePath) + "." + $newId

            # Task signal file and output file
            $taskSignalFilePath = [System.IO.Path]::Combine($shortTaskLocation, $taskName + ".txt")
            $taskLogFilePath = [System.IO.Path]::Combine($shortTaskLocation, $taskName + "output.txt")

            # Task invoker script : Dump core script invocation code in a wrapper script, so as to avoid 261 char limit in schtasks.exe
            $taskInvokerFilePath = [System.IO.Path]::Combine($shortTaskLocation, "TaskInvokerScript.ps1")

            $fileContent = "& $newCoreScriptFilePath " + $arguments
            $fileContent | Out-File $taskInvokerFilePath
            Write-Host "Writing main script invocation code in a wrapper script : $newCoreScriptFilePath"
            Write-Host "Contents written : $fileContent"
    
            $command = 'powershell powershell -ExecutionPolicy Bypass -NoProfile -File ' + $newGetSignalScriptFilePath + ' ' + $taskInvokerFilePath + ' ' + $taskSignalFilePath + ' >' + $taskLogFilePath
            Write-Host "Scheduling task with command : $command"
            $exitCode = Invoke-Command -ErrorVariable err -OutVariable out -ScriptBlock { schtasks.exe /create /TN:$taskName /TR:$args /F /RL:HIGHEST /SC:MONTHLY /RU:SYSTEM; schtasks.exe /run /TN:$taskName ; Sleep 10 ; schtasks.exe /change /disable /TN:$taskName } -ArgumentList $command
            Write-Host "Schtasks output : $out"
            Write-Host "Schtasks error : $err"

            if ($exitCode -ne 0)
            {
                Write-Host "Non zero exit code received while authoring schedule tasks : $exitCode"
                return $exitCode
            }

            Get-ScheduledTask -TaskName $taskName | Out-Null
            Write-Host "Scheduled task exists"

            # Log the taskname so that next wait function may read it
            $taskName | Out-File $taskNameFile
            Write-Host "Logged the taskname : $taskName to file : $taskNameFile"
    
            if ($waitForCompletion -eq $true)
            {
                Write-Host "Need to wait for task to complete"
                $exitCode = WaitForTaskCompletion $taskName $timeoutInMins $cleanup
                Write-Host "Exit code returned by wait for task script : $exitCode"
            }

        }
        catch
        {
            if ($_ -ne $null) { Write-Host "Exception : $_.Message" }
            return -1
        }

        Write-Host "Returning from RunTask with exit code : $exitCode"
        return $exitCode
    }

}



function WaitForTaskCompletion {

    <#
        .SYNOPSIS
        Waits for a scheduled task to complete which was previously created by RunTask module, and keeps dumping live logs from the task

        .DESCRIPTION
        Waits for a scheduled task to complete which was previously created by RunTask module, and keeps dumping live logs from the task

        .EXAMPLE
        WaitForTaskCompletion -taskName $taskName timeoutInMins 60 -cleanup $true

        .INPUTS
        None.
    #>
    Param (

        [string] $taskName,

        [string] $timeoutInMins = 80,

        [bool] $cleanup = $false

    )

    PROCESS
    {
        try
        {
            $ErrorActionPreference = 'Stop'

            if ($taskName -eq $null -or $taskName -eq "") { Write-Host "Reading Task name from : $taskNameFile"; $taskName = Get-Content $taskNameFile }
            Write-Host "Task name : $taskName"

            $taskOutputFilePath = "$shortTaskLocation\$taskName" + "output.txt"
            $taskSignalFilePath = "$shortTaskLocation\$taskName" + ".txt"

            Write-Host "Task Output file  : $taskOutputFilePath"
            Write-Host "Task Signal file : $taskSignalFilePath"

            $exitCode = WaitForSignalFile_Private -signalFilePath $taskSignalFilePath -taskOutputFile $taskOutputFilePath -timeOutInMins $timeoutInMins

            if ($cleanup -eq $true)
            {
                # Delete task directory
                Remove-Item $shortTaskLocation -Recurse -Force

                # Delete the task
                Invoke-Command -ScriptBlock { schtasks.exe /delete /TN:$taskName /F }
            }

            return $exitCode
        }
        catch
        {
            if ($_ -ne $null) { Write-Host "Exception : $_.Message" }
            return -1
        }        
    }
}


Function LogTail_Private()
{
    Param (
        [string] $FilePath,
        [string] $LogIndex
    )

        if ((Test-Path -Path $FilePath) -eq $false)
        {
            return
        }
        
        $Total = (Get-Content $FilePath).Length
        if ($LogIndex -ne $Total)
        {
            Get-Content $FilePath -Tail ($Total - $LogIndex) | Write-Host
            $LogIndex = $total
        }
        $LogIndex

}

Function WaitForSignalFile_Private() {
    Param (
        [string] $signalFilePath,
        [string] $taskOutputFilePath,
        [string] $timeOutInMins
    )

    # Now wait for the exit signal file
    $exitCode = -10
    $startTime = Get-Date
    $pollingTimeInSeconds = 3

    # Default code, means timeout
    $timeout = $false

    $logFileReadIndex = 0
    while ($timeout -eq $false)
    {
        if (Test-Path $signalFilePath)
        {
            $exitCode = Get-Content $signalFilePath -TotalCount 1
            $logFileReadIndex = LogTail_Private -FilePath $taskOutputFilePath -LogIndex $logFileReadIndex
            Write-Host "Task signal received ! task exited with code = $exitCode"
            break
        }

        # Read live logs from the task
        $logFileReadIndex = LogTail_Private -FilePath $taskOutputFilePath -LogIndex $logFileReadIndex

        Start-Sleep -s $pollingTimeInSeconds

        $now = Get-Date
        $timeout = (New-TimeSpan $startTime $now).TotalMinutes -gt $timeOutInMins
    }

    return $exitCode
}

<##################################################################################################

    Usage Example
    =============

    Import-Module <path to RunTask.psm1>
    RunTask -coreScriptFilePath "C:\Script\InstallProduct.ps1" -arguments "arg1 arg2"
    

    Help / Documentation
    ====================
    - To view a cmdlet's help description: Get-help "cmdlet-name" -Detailed
    - To view a cmdlet's usage example: Get-help "cmdlet-name" -Examples


    Pre-Requisites
    ==============
    - This module must run with Administrator privileges.


    Known Issues
    ============
    - 
##################################################################################################>

$shortTaskLocation = "${env:Systemdrive}\_TaskScripts_"
$taskNameFile = "$shortTaskLocation\taskName.txt"

function RunTask {

    <#
        .SYNOPSIS
        Creates a new scheduled task and waits for the task to complete, while dumping live logs continuously

        .DESCRIPTION
        Creates a new scheduled task and waits for the task to complete, while dumping live logs continuously

        .EXAMPLE
        RunTask -coreScriptFilePath "C:\Script\InstallProduct.ps1" -arguments "arg1 arg2"
        RunTask -coreScriptFilePath "C:\Script\InstallProduct.ps1" -arguments "arg1 arg2" -waitForCompletion $true -cleanup $true
        RunTask -coreScriptFilePath "C:\Script\InstallProduct.ps1" -arguments "arg1 arg2" -waitForCompletion $true -timeoutInMins 30 -cleanup $true

        .INPUTS
        None.
    #>
    Param (

        [Parameter(Mandatory=$true)]
        [string] $coreScriptFilePath,

        [string] $arguments,

        [bool] $waitForCompletion = $true,

        [string] $timeoutInMins = 80,

        [bool] $cleanup = $false
    )

    PROCESS
    {

        $ErrorActionPreference = 'Stop'

        try
        {
            Write-Host "ScriptName : $coreScriptFilePath"
            Write-Host "Arguments : $arguments"
            Write-Host "Wait for Completion : $waitForCompletion"
            Write-Host "Timeout : $timeoutInMins"

            # Create a shorter task directory
            New-Item $shortTaskLocation -Type Directory -Force | Out-Null
            Write-Host "Directory to be used for task : $shortTaskLocation"

            # Get Signal script path
            $getSignalScriptFilePath = [System.IO.Path]::Combine($PSScriptRoot, "StartProcess_GetSignal.ps1")

            # Copy the required scripts to task directory
            Copy-Item $getSignalScriptFilePath $shortTaskLocation -Force
            Copy-Item $coreScriptFilePath $shortTaskLocation -Force
            Write-Host "Copied scripts to a shorter task directory : $shortTaskLocation"

            # New file paths
            $newCoreScriptFilePath = [System.IO.Path]::Combine($shortTaskLocation, [System.IO.Path]::GetFileName($coreScriptFilePath))
            $newGetSignalScriptFilePath = [System.IO.Path]::Combine($shortTaskLocation, [System.IO.Path]::GetFileName($getSignalScriptFilePath))

            # Task Name
            $newId = (Get-Random -minimum 1 -maximum 101).ToString()
            $taskName = [System.IO.Path]::GetFileNameWithoutExtension($coreScriptFilePath) + "." + $newId

            # Task signal file and output file
            $taskSignalFilePath = [System.IO.Path]::Combine($shortTaskLocation, $taskName + ".txt")
            $taskLogFilePath = [System.IO.Path]::Combine($shortTaskLocation, $taskName + "output.txt")

            # Task invoker script : Dump core script invocation code in a wrapper script, so as to avoid 261 char limit in schtasks.exe
            $taskInvokerFilePath = [System.IO.Path]::Combine($shortTaskLocation, "TaskInvokerScript.ps1")

            $fileContent = "& $newCoreScriptFilePath " + $arguments
            $fileContent | Out-File $taskInvokerFilePath
            Write-Host "Writing main script invocation code in a wrapper script : $newCoreScriptFilePath"
            Write-Host "Contents written : $fileContent"
    
            $command = 'powershell powershell -ExecutionPolicy Bypass -NoProfile -File ' + $newGetSignalScriptFilePath + ' ' + $taskInvokerFilePath + ' ' + $taskSignalFilePath + ' >' + $taskLogFilePath
            Write-Host "Scheduling task with command : $command"
            Invoke-Command -ErrorVariable err -OutVariable out -ScriptBlock { schtasks.exe /create /TN:$taskName /TR:$args /F /RL:HIGHEST /SC:MONTHLY /RU:SYSTEM; schtasks.exe /run /TN:$taskName ; Sleep 10 ; schtasks.exe /change /disable /TN:$taskName } -ArgumentList $command
            $exitCode = $LASTEXITCODE
            Write-Host "Schtasks output : $out"
            Write-Host "Schtasks error : $err"

            if ($exitCode -ne 0)
            {
                Write-Host "Non zero exit code received while authoring schedule tasks : $exitCode"
                return $exitCode
            }

            Get-ScheduledTask -TaskName $taskName | Out-Null
            Write-Host "Scheduled task exists"

            # Log the taskname so that next wait function may read it
            $taskName | Out-File $taskNameFile
            Write-Host "Logged the taskname : $taskName to file : $taskNameFile"
    
            if ($waitForCompletion -eq $true)
            {
                Write-Host "Need to wait for task to complete"
                $exitCode = WaitForTaskCompletion $taskName $timeoutInMins $cleanup
                Write-Host "Exit code returned by wait for task script : $exitCode"
            }

        }
        catch
        {
            if ($_ -ne $null) { Write-Host "Exception : $_.Message" }
            return -1
        }

        Write-Host "Returning from RunTask with exit code : $exitCode"
        return $exitCode
    }

}



function WaitForTaskCompletion {

    <#
        .SYNOPSIS
        Waits for a scheduled task to complete which was previously created by RunTask module, and keeps dumping live logs from the task

        .DESCRIPTION
        Waits for a scheduled task to complete which was previously created by RunTask module, and keeps dumping live logs from the task

        .EXAMPLE
        WaitForTaskCompletion -taskName $taskName timeoutInMins 60 -cleanup $true

        .INPUTS
        None.
    #>
    Param (

        [string] $taskName,

        [string] $timeoutInMins = 80,

        [bool] $cleanup = $false

    )

    PROCESS
    {
        try
        {
            $ErrorActionPreference = 'Stop'

            if ($taskName -eq $null -or $taskName -eq "") { Write-Host "Reading Task name from : $taskNameFile"; $taskName = Get-Content $taskNameFile }
            Write-Host "Task name : $taskName"

            $taskOutputFilePath = "$shortTaskLocation\$taskName" + "output.txt"
            $taskSignalFilePath = "$shortTaskLocation\$taskName" + ".txt"

            Write-Host "Task Output file  : $taskOutputFilePath"
            Write-Host "Task Signal file : $taskSignalFilePath"

            $exitCode = WaitForSignalFile_Private -signalFilePath $taskSignalFilePath -taskOutputFile $taskOutputFilePath -timeOutInMins $timeoutInMins

            if ($cleanup -eq $true)
            {
                # Delete task directory
                Remove-Item $shortTaskLocation -Recurse -Force

                # Delete the task
                Invoke-Command -ScriptBlock { schtasks.exe /delete /TN:$taskName /F }
            }

            return $exitCode
        }
        catch
        {
            if ($_ -ne $null) { Write-Host "Exception : $_.Message" }
            return -1
        }        
    }
}


Function LogTail_Private()
{
    Param (
        [string] $FilePath,
        [string] $LogIndex
    )

        if ((Test-Path -Path $FilePath) -eq $false)
        {
            return
        }
        
        $Total = (Get-Content $FilePath).Length
        if ($LogIndex -ne $Total)
        {
            Get-Content $FilePath -Tail ($Total - $LogIndex) | Write-Host
            $LogIndex = $total
        }
        $LogIndex

}

Function WaitForSignalFile_Private() {
    Param (
        [string] $signalFilePath,
        [string] $taskOutputFilePath,
        [string] $timeOutInMins
    )

    # Now wait for the exit signal file
    $exitCode = -10
    $startTime = Get-Date
    $pollingTimeInSeconds = 3

    # Default code, means timeout
    $timeout = $false

    $logFileReadIndex = 0
    while ($timeout -eq $false)
    {
        if (Test-Path $signalFilePath)
        {
            $exitCode = Get-Content $signalFilePath -TotalCount 1
            $logFileReadIndex = LogTail_Private -FilePath $taskOutputFilePath -LogIndex $logFileReadIndex
            Write-Host "Task signal received ! task exited with code = $exitCode"
            break
        }

        # Read live logs from the task
        $logFileReadIndex = LogTail_Private -FilePath $taskOutputFilePath -LogIndex $logFileReadIndex

        Start-Sleep -s $pollingTimeInSeconds

        $now = Get-Date
        $timeout = (New-TimeSpan $startTime $now).TotalMinutes -gt $timeOutInMins
    }

    return $exitCode
}

export-modulemember -function RunTask
export-modulemember -function WaitForTaskCompletion