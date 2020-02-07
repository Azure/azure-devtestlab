# Downloads the Azure DevOps Pipelines Agent and installs specified instances on the new machine
# under C:\agents\ and registers with the Azure DevOps Pipelines agent pool

[CmdletBinding()]
Param
(
    [Parameter()]
    [string]$Account,

    [Parameter()]
    [String]$PersonalAccessToken,

    [Parameter()]
    [string]$AgentName,

    [Parameter()]
    [string]$AgentInstallLocation,

    [Parameter()]
    [string]$AgentNamePrefix,

    [Parameter()]
    [string]$PoolName,

    [Parameter()]
    [int] $AgentCount,

    [Parameter()]
    [bool] $Overwrite
)

###################################################################################################
#
# PowerShell configurations
#

# NOTE: Because the $ErrorActionPreference is "Stop", this script will stop on first failure.
#       This is necessary to ensure we capture errors inside the try-catch-finally block.
$ErrorActionPreference = "Stop"

# Ensure we force use of TLS 1.2 for all downloads.
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12

# Ensure we set the working directory to that of the script.
Push-Location $PSScriptRoot

###################################################################################################
#
# Handle all errors in this script.
#
trap {
    # NOTE: This trap will handle all errors. There should be no need to use a catch below in this
    #       script, unless you want to ignore a specific error.
    $message = $error[0].Exception.Message
    if ($message) {
        Write-Host -Object "ERROR: $message" -ForegroundColor Red
    }
    
    # IMPORTANT NOTE: Throwing a terminating error (using $ErrorActionPreference = "Stop") still
    # returns exit code zero from the PowerShell script when using -File. The workaround is to
    # NOT use -File when calling this script and leverage the try-catch-finally block and return
    # a non-zero exit code from the catch block.
    exit -1
}

#
# Test the last exit code correctly.
#
function Test-LastExitCode {
    param
    (
        [string] $Message = ''
    )

    # Whenever we execute commands such as '& somecommand' or via Invoke-Expression, we should always
    # check the exit code, so we can decide to stop processing at that time, by throwing an exception.
    $exitCode = $LASTEXITCODE
    if ($exitCode -and $exitCode -ne 0) {
        if ($Message) {
            if (-not $Message.EndsWith('.')) {
                $Message += '.'
            }
            $Message += ' '
        }
        $Message += "Last command exited with error code $exitCode"
        throw $Message
    }
    Write-Output "Completed with exit code: $exitCode"
}
###################################################################################################
#
# Main execution block.
#
try {
    Write-Output "Entering powershell task" 
    Write-Output "Current folder: $PSScriptRoot" 

    Write-Output "Validating parameters..."

    if ([string]::IsNullOrWhiteSpace($Account)) {
        throw "Account parameter is required."
    }
    if ([string]::IsNullOrWhiteSpace($PersonalAccessToken)) {
        throw "PersonalAccessToken parameter is required."
    }
    if ([string]::IsNullOrWhiteSpace($PoolName)) {
        throw "PoolName parameter is required."
    }
    if ([string]::IsNullOrWhiteSpace($AgentName)) {
        $AgentName = $env:COMPUTERNAME
    }
    if (-not [string]::IsNullOrWhiteSpace($AgentNamePrefix)) {
        $AgentName = ("{0}-{1}" -f $AgentNamePrefix, $AgentName)
    }
    if ([string]::IsNullOrWhiteSpace($AgentInstallLocation)) {
        $AgentInstallLocation = "c:\agents";
    }

    #Create a temporary directory where to download from Azure DevOps the agent package (vsts-agent.zip) and then launch the configuration.
    $agentTempFolderName = Join-Path $env:temp ([System.IO.Path]::GetRandomFileName())
    New-Item -ItemType Directory -Force -Path $agentTempFolderName
    Write-Output "Temporary Agent download folder: $agentTempFolderName" 

    $serverUrl = "https://dev.azure.com/$Account"
    Write-Output "Server URL: $serverUrl" 

    $retryCount = 3
    $retries = 1
    Write-Output "Downloading Agent install files" 
    do {
        try {
            Write-Output "Fetching download URL for latest Azure DevOps agent..."
            $vstsAgentUrl = "$serverUrl/_apis/distributedtask/packages/agent/win7-x64?`$top=1&api-version=3.0"
            $basicAuth = (":{0}" -f $PersonalAccessToken)
            $basicAuth = [System.Text.Encoding]::UTF8.GetBytes($basicAuth)
            $basicAuth = [System.Convert]::ToBase64String($basicAuth)
            $headers = @{ Authorization = ("Basic {0}" -f $basicAuth) }
            [array] $agentList = Invoke-WebRequest -Uri $vstsAgentUrl -Headers $headers -Method Get -ContentType application/json -UseBasicParsing | ConvertFrom-Json
            $agent = $agentList.value[0]
           
            Write-Output "Agent will be downloaded to: '$agentTempFolderName'"

            $agentPackagePath = "$agentTempFolderName\agent.zip"

            if (Test-Path -Path $agentPackagePath) {
                Write-Output "Directory $agentTempFolderName is not empty...Removing all contents..."
                Remove-Item "$agentTempFolderName/*" -Force -Recurse
            }

            $downloadUrl = $agent.downloadUrl;

            Write-Output "Downloading agent from: $downloadUrl"

            Invoke-WebRequest -Uri $agent.downloadUrl -Headers $headers -Method Get -OutFile  "$agentPackagePath" -UseBasicParsing | Out-Null

            Write-Output "Downloaded agent successfully on attempt $retries" 
            break
        }
        catch {
            $exceptionText = ($_ | Out-String).Trim()
            Write-Output "Exception occured downloading agent: $exceptionText in try number $retries" 
            $retries++
            Start-Sleep -Seconds 30 
        }
    } 
    while ($retries -le $retryCount)

    for ($i = 1; $i -lt $AgentCount + 1; $i++) {
        $Agent = ($AgentName + "-" + $i)


        # Construct the agent folder under the main (hardcoded) C: drive.
        $agentInstallationPath = Join-Path $AgentInstallLocation $Agent

        #Test if the directory already exist, which probably means agent also exists
        if (-not $Overwrite -and (Test-Path $agentInstallationPath)) {
            Write-Output "Directory $agentInstallationPath not empty..Overwrite is set to 'false', skipping..."
            continue;
        }

        # Create the directory for this agent.
        New-Item -ItemType Directory -Force -Path $agentInstallationPath

        # Set the current directory to the agent dedicated one previously created.
        Push-Location -Path $agentInstallationPath
	
        Write-Output "Extracting the zip file for the agent" 
        $destShellFolder = (new-object -com shell.application).namespace("$agentInstallationPath")
        $destShellFolder.CopyHere((new-object -com shell.application).namespace("$agentTempFolderName\agent.zip").Items(), 16)

        # Removing the ZoneIdentifier from files downloaded from the internet so the plugins can be loaded
        # Don't recurse down _work or _diag, those files are not blocked and cause the process to take much longer
        Write-Output "Unblocking files" 
        Get-ChildItem -Recurse -Path $agentInstallationPath | Unblock-File | out-null

        # Retrieve the path to the config.cmd file.
        $agentConfigPath = [System.IO.Path]::Combine($agentInstallationPath, 'config.cmd')
        Write-Output "Agent Location = $agentConfigPath" 
        if (![System.IO.File]::Exists($agentConfigPath)) {
            throw "File not found: $agentConfigPath"
        }

        # Call the agent with the configure command and all the options (this creates the settings file) without prompting
        # the user or blocking the cmd execution
        Write-Output "Configuring agent '$($Agent)'" 		
        .\config.cmd --unattended --url $serverUrl --auth PAT --token $PersonalAccessToken --pool $PoolName --agent $Agent --runasservice
        Test-LastExitCode

        Pop-Location
    }

    Write-Output "Exiting InstallVSTSAgent.ps1" 
}
finally {
    Pop-Location
}

