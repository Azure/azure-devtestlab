 <#
    .SYNOPSIS
        This script shutdowns the machine if the user hasn't been active.

    .DESCRIPTION
        This script verifies if: the user is active, CPU and disk usage and shutsdown the machine if the user is no longer active.

    .PARAMETER MaxIdleTime
        Max allowed idle (in minutes)

    .PARAMETER MonitoringIntervalTime
        Interval for CPU and disk monitoring (in minutes). No more than 15 minutes

    .PARAMETER timeout
        Timeout before actual shutdown after shutdown trigger (in minutes). No more than 10 minutes

    .PARAMETER cpuIdleThreshold
        % cpu on idle 

    .PARAMETER diskIdleThreshold
        % disk on idle  
    
    .EXAMPLE
        PS C:\> ShutdownOnIdleV2

    .EXAMPLE
        PS C:\> ShutdownOnIdleV2 -MaxIdleTime 120 -cpuIdleThreshold 80 -diskIdleThreshold 80

#>
 
 [CmdletBinding()]
param
(
    [Parameter(Mandatory=$false, HelpMessage="Max allowed idle (in minutes)")]
    [int] $MaxIdleTime = 60,

    [Parameter(Mandatory=$false, HelpMessage="Interval for CPU and disk monitoring (in minutes). No more than 15 minutes")]
    [int] $MonitoringIntervalTime = 10,

    [Parameter(Mandatory=$false, HelpMessage="Timeout before actual shutdown after shutdown trigger (in minutes). No more than 10 minutes")]
    [int] $timeout = 3,

    [Parameter(Mandatory=$false, HelpMessage="% cpu on idle")]
    [int] $cpuIdleThreshold = 70,
    
    [Parameter(Mandatory=$false, HelpMessage="% disk on idle")]
    [int] $diskIdleThreshold = 70
)


function Get-LoggedInUser
{
<#
    .SYNOPSIS
        Shows all the users currently logged in

    .DESCRIPTION
        Shows the users currently logged into the specified computernames

    .PARAMETER ComputerName
        One or more computernames

    .EXAMPLE
        PS C:\> Get-LoggedInUser
        Shows the users logged into the local system

    .EXAMPLE
        PS C:\> Get-LoggedInUser -ComputerName server1,server2,server3
        Shows the users logged into server1, server2, and server3

    .EXAMPLE
        PS C:\> Get-LoggedInUser  | where idletime -gt "1.0:0" | ft
        Get the users who have been idle for more than 1 day.  Format the output
        as a table.

        Note the "1.0:0" string - it must be either a system.timespan datatype or
        a string that can by converted to system.timespan.  Examples:
            days.hours:minutes
            hours:minutes
#>

    [CmdletBinding()]
    param
    (
        [ValidateNotNullOrEmpty()]
        [String[]]$ComputerName = $env:COMPUTERNAME
    )

    $out = @()

    ForEach ($computer in $ComputerName)
    {
        try { if (-not (Test-Connection -ComputerName $computer -Quiet -Count 1 -ErrorAction Stop)) { Write-Warning "Can't connect to $computer"; continue } }
        catch { Write-Warning "Can't test connect to $computer"; continue }

        $quserOut = quser.exe /SERVER:$computer 2>&1
        if ($quserOut -match "No user exists")
        { 
            #Write-Warning "No users logged in to $computer";  
            continue;
        }

        $users = $quserOut -replace '\s{2,}', ',' |
        ConvertFrom-CSV -Header 'username', 'sessionname', 'id', 'state', 'idleTime', 'logonTime' |
        Add-Member -MemberType NoteProperty -Name ComputerName -Value $computer -PassThru

        $users = $users[1..$users.count]

        for ($i = 0; $i -lt $users.count; $i++)
        {
            if ($users[$i].sessionname -match '^\d+$')
            {
                #$users[$i].logonTime = $users[$i].idleTime
                $users[$i].idleTime = $users[$i].STATE
                $users[$i].STATE = $users[$i].ID
                $users[$i].ID = $users[$i].SESSIONNAME
                $users[$i].SESSIONNAME = $null
            }

            # cast the correct datatypes
            $users[$i].ID = [int]$users[$i].ID

            $idleString = $users[$i].idleTime
            if ($idleString -eq '.') { $users[$i].idleTime = 0 }

            # if it's just a number by itself, insert a '0:' in front of it. Otherwise [timespan] cast will interpret the value as days rather than minutes
            if ($idleString -match '^\d+$')
            { $users[$i].idleTime = "0:$($users[$i].idleTime)" }

            # if it has a '+', change the '+' to a colon and add ':0' to the end
            if ($idleString -match "\+")
            {
                $newIdleString = $idleString -replace "\+", ":"
                $newIdleString = $newIdleString + ':0'
                $users[$i].idleTime = $newIdleString
            }

            $users[$i].idleTime = [timespan]$users[$i].idleTime
            #$users[$i].logonTime = [datetime]$users[$i].logonTime
        }
        $users = $users | Sort-Object -Property idleTime
        $out += $users
    }
  
    Write-Output $out
}

function Get-AverageCounters {

        # take samples every 5 seconds during the monitoring interval time
        $maxSamples = [convert]::ToInt64(($MonitoringIntervalTime*60)/5)

        # measure the CPU idle
        $cpuJob = Start-Job -Name CPUIdle {
            param([int64] $maxSamples)
            $cpuIdle = Get-Counter -Counter "\Processor(_Total)\% Idle Time" -SampleInterval 5 -MaxSamples $maxSamples

            $cpuIdleAverage = ($cpuIdle | Select-Object -ExpandProperty  CounterSamples | Group-Object -Property InstanceName | ForEach-Object { 
                $_ | Select-Object @{n='Average';e={($_.Group.CookedValue | Measure-Object -Average).Average}};
            }).Average

            return $cpuIdleAverage
        } -ArgumentList ($maxSamples)

        # measure the disk idle
        $diskJob = Start-Job -Name DiskIdle {
            param([int64] $maxSamples)
            $diskIdle = Get-Counter -Counter "\PhysicalDisk(*)\% Idle Time" -SampleInterval 5 -MaxSamples $maxSamples

            # take the average of the first disk (disk C:\)
            $diskIdleAverage = ($diskIdle | Select-Object -ExpandProperty  CounterSamples | Group-Object -Property InstanceName | ForEach-Object { 
                $_ | Select-Object @{n='Average';e={($_.Group.CookedValue | Measure-Object -Average).Average}};
            }).Average[0]

            return $diskIdleAverage
        } -ArgumentList ($maxSamples)

        # wait for jobs running in parallel
        Wait-Job -Job $cpuJob, $diskJob

        $result = "" | Select-Object -Property cpuIdleAverage, diskIdleAverage
        $result.cpuIdleAverage = Receive-Job -Job $cpuJob
        $result.diskIdleAverage = Receive-Job -Job $diskJob
        return $result

}

function ShutdownMachine {
    
    if ($timeout -gt 10){
        $timeout = 10
    }

    $seconds = $timeout*60

    # force the shutdown with the specified timeout. It suppresses possible error messages due to a call to shutdown.exe when shutdown has been already scheduled
    shutdown.exe -s -f -t $seconds -d u:0:0 -c "Windows will shut down in $timeout minutes" 2>$null

    # if exitcode is 1190, a shutdown has been already scheduled
    #if ($LASTEXITCODE -eq 1190)
    #{
    #    Write-Warning "A shutdown is already scheduled"
    #}

}


## MAIN SCRIPT 

$checkedBeforeIdleThreshold = $false
$lastTimestampUserLogged = Get-Date

#to avoid negative numbers
if ($MonitoringIntervalTime -gt $MaxIdleTime){
    $MonitoringIntervalTime = $MaxIdleTime
}

#limit the monitoring interval time for machine idle to 15 minutes
if ($MonitoringIntervalTime -gt 15){
    $MonitoringIntervalTime = 15
}

 while(1) {
    
	$queryUser = Get-LoggedInUser
    
    #there is no user logged (null string)
    if ($queryUser -eq $null){

        Add-Content c:\temp\logIdle.txt "Last time user logged: $lastTimestampUserLogged"
        Add-Content c:\temp\logIdle.txt "No users logged"
        #Write-Warning "Last time user logged: $lastTimestampUserLogged";

        $currentDateTime = Get-Date
        # if there are no users logged for the MaxIdleTime, it stops the machine
        if ($currentDateTime -ge $lastTimestampUserLogged.AddMinutes($MaxIdleTime)){
            
            #Write-Warning "Elapsed $MaxIdleTime with no user logged";

            Add-Content c:\temp\logIdle.txt "Timestamp: $lastTimestampUserLogged"
            Add-Content c:\temp\logIdle.txt "Elapsed $MaxIdleTime with no user logged"
            
            ShutdownMachine

        }
       
    }

    elseIf ($queryUser.username -ne $null){

        $lastTimestampUserLogged = Get-Date
        $idleMinutes = $queryUser.idleTime.TotalMinutes

        #Write-Warning "Timestamp: $lastTimestampUserLogged"
        Add-Content c:\temp\logIdle.txt "Timestamp: $lastTimestampUserLogged"
        #Write-Warning "User idletime: $idleMinutes"
        Add-Content c:\temp\logIdle.txt "User idletime: $idleMinutes"

        #check the user interaction and the previous counters
        if($idleMinutes -ge $MaxIdleTime){

            # if we miss to measure before, we assure to get a measure now. Otherwise, we take the last result
            if (!$checkedBeforeIdleThreshold){
                
                #Write-Warning "Elapsed $idleMinutes minutes with no user interaction. Starting counter after the max idle time .."
                Add-Content c:\temp\logIdle.txt "Elapsed $idleMinutes minutes with no user interaction. Starting counter after the max idle time .."

                $result = Get-AverageCounters          
                
            }

            # check again the user interaction, in case the user interacted with the machine again during the measurement
            $queryUser = Get-LoggedInUser
            $idleMinutes = $queryUser.idleTime.TotalMinutes

            # if there is no user interaction for the MaxIdleTime and if the CPU and disks are considered in idle during the last MonitoringIntervalTime, it stops the machine
            if (($result.cpuIdleAverage -ge $cpuIdleThreshold) -and ($result.diskIdleAverage -ge $diskIdleThreshold) -and ($idleMinutes -ge $MaxIdleTime)){
                
                #Write-Warning "Elapsed $idleMinutes minutes with no user interaction. CPU and disk are not used. Shutdown..."
                Add-Content c:\temp\logIdle.txt "Elapsed $idleMinutes minutes with no user interaction. CPU and disk are not used. Shutdown..."
                
                ShutdownMachine

            }
            
            $checkedBeforeIdleThreshold = $false

        }

        # start to monitor CPU and disk when we are approaching the MaxIdleTime
        elseIf ($idleMinutes -ge $MaxIdleTime - $MonitoringIntervalTime){

            #Write-Warning "Elapsed $idleMinutes minutes with no user interaction. Starting counter $MonitoringIntervalTime minutes before the threshold.."
            Add-Content c:\temp\logIdle.txt "Elapsed $idleMinutes minutes with no user interaction. Starting counter $MonitoringIntervalTime minutes before the threshold.."

            $result = Get-AverageCounters 

            $checkedBeforeIdleThreshold = $true

            # check again the user interaction, in case the user interacted with the machine again during the measurement
            $queryUser = Get-LoggedInUser
            $idleMinutes = $queryUser.idleTime.TotalMinutes

            # if there is no user interaction for the MaxIdleTime and if the CPU and disks are considered in idle during the last MonitoringIntervalTime, it stops the machine
            if (($result.cpuIdleAverage -ge $cpuIdleThreshold) -and ($result.diskIdleAverage -ge $diskIdleThreshold) -and ($idleMinutes -ge $MaxIdleTime)){
                
                #Write-Warning "Elapsed $idleMinutes minutes with no user interaction. CPU and disk are not used. Shutdown..."
                Add-Content c:\temp\logIdle.txt "Elapsed $idleMinutes minutes with no user interaction. CPU and disk are not used. Shutdown..."
               
                ShutdownMachine

            }         
        }
    }

    # loop according to MaxIdleTime
    Start-Sleep -Seconds ([convert]::ToInt64(($MaxIdleTime*60)/10))
    
}
