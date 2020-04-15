$SleepTime = 1
$Timeout = 300
$HdpContainer = 'sandbox-hdp'
$ProxyContainer = 'sandbox-proxy'

function Start-Container{
    Param([string]$containerName)
     
        Start-Process -FilePath 'docker.exe' -WindowStyle Hidden -ArgumentList "start $containerName" -Wait

        Write-Host ''
        Write-Host "Starting $containerName container" -NoNewLine 
        
        do
        {
            Write-Host '.'
            Start-Sleep -Seconds $SleepTime
            $docker = Start-Process -FilePath 'docker.exe' -WindowStyle Hidden -ArgumentList "container top $containerName" -Wait
        }
        while ($docker.ExitCode -gt 0 -and $timer.Elapsed.TotalSeconds -lt $Timeout)

        $result = $true
        if ($docker.ExitCode -gt 0)
        {
            $result = $false
            Write-Host ''
            Write-Error -Message "Error: Container $containerName failed to start." -Category ResourceUnavailable
        }

        return $result
}

$timer = [Diagnostics.Stopwatch]::StartNew()

Write-Host ''
Write-Host '*****************************************************************************************************************'
Write-Host 'Starting the HortonWorks HDP and proxy sandbox environment. This may take up to 5 minutes to finish.'
Write-Host 'Please do NOT close this window until the sandbox environment has finished starting.'
Write-Host '*****************************************************************************************************************'
Write-Host ''
Write-Host 'Waiting for Docker to start' -NoNewline 

do 
{
    #Wait for docker since it should be configured on the VM to automatically start when the VM starts
    $docker = Start-Process -FilePath 'docker.exe' -WindowStyle Hidden -ArgumentList 'ps -a' -Wait -PassThru

    Write-Host '.' -NoNewline
    Start-Sleep -Seconds $SleepTime
} 
while ($docker.ExitCode -gt 0 -and $timer.Elapsed.TotalSeconds -lt $Timeout)

if ($docker.ExitCode -gt 0)
{
    Write-Host ''
    Write-Error -Message 'Error: Docker failed to start.' -Category ResourceUnavailable
    Read-Host -Prompt 'Press Enter to close'
}
else
{
    Write-Host ''
    
    #Start containers
    if (Start-Container($HDPContainer))
    {
        if (Start-Container($ProxyContainer))
        {
            #Wait some extra time to allow the proxy container to connect
            Write-Host ''
            Write-Host 'Waiting for the sandbox-proxy container to connect' -NoNewline 

            for ($i=0; $i -lt 30; $i++)
            {
                Write-Host '.' -NoNewline 
                Start-Sleep -Seconds $SleepTime
            }
            
            Write-Host ''
            Write-Host ''
            Write-Host 'Launching the browser: http://localhost:1080'

            $browser = Start-Process 'http://localhost:1080/'

            Write-Host ''
            if ($docker.ExitCode -gt 0)
            {
                Write-Host 'Launch the browser and open the following url: http://localhost:1080'
                
            }
            
            Write-Host 'The sandbox environment has finished starting!'
        }
    }
}

Write-Host ''
Read-Host -Prompt 'Press Enter to close'