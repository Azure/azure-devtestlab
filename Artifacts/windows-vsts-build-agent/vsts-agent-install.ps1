# Downloads the Visual Studio Online Build Agent, installs on the new machine, registers with the Visual
# Studio Online account, and adds to the specified build agent pool

[CmdletBinding()]
Param(
    [Parameter(Mandatory=$true)]
    $vstsAccount,
    
    [Parameter(Mandatory=$true)]
    $vstsUserPassword,
    
    [Parameter(Mandatory=$true)]
    $agentName,
    
    [Parameter(Mandatory=$true)]
    $poolname,
    
    [Parameter(Mandatory=$true)]
    $driveLetter
)

Write-Verbose "Entering vsts-agent-install.ps1" -verbose

if ($driveLetter.length -ne 1)
{
    Write-Error "The drive letter must be 1 character only; exiting."
    exit -1
}

$vstsUser = "AzureDevTestLabs"

$currentLocation = Split-Path -parent $MyInvocation.MyCommand.Definition
Write-Verbose "Current folder: $currentLocation" -Verbose

# Create a temporary directory to download from VSTS the agent package (agent.zip) to, and then launch the configuration.
$agentTempFolderName = Join-Path $env:temp ([System.IO.Path]::GetRandomFileName())
New-Item -ItemType Directory -Force -Path $agentTempFolderName
Write-Verbose "Temporary agent download folder: $agentTempFolderName" -Verbose

$serverUrl = "https://$vstsAccount.visualstudio.com"
Write-Verbose "Server URL: $serverUrl" -Verbose

$vstsAgentUrl = "$serverUrl/_apis/distributedtask/packages/agent"
Write-Verbose "VSTS agent URL: $vstsAgentUrl" -Verbose

$retryCount = 3
$retries = 1
Write-Verbose "Downloading agent install files" -Verbose
do
{
    try
    {
        $basicAuth = ("{0}:{1}" -f $vstsUser, $vstsUserPassword) 
        $basicAuth = [System.Text.Encoding]::UTF8.GetBytes($basicAuth)
        $basicAuth = [System.Convert]::ToBase64String($basicAuth)
        $headers = @{ Authorization = ("Basic {0}" -f $basicAuth) }

        Invoke-WebRequest -Uri $vstsAgentUrl -headers $headers -Method Get -OutFile "$agentTempFolderName\agent.zip"
        Write-Verbose "Downloaded agent successfully on attempt $retries" -Verbose
        break
    }
    catch
    {
        $exceptionText = ($_ | Out-String).Trim()
        Write-Verbose "Exception occured downloading agent: $exceptionText in try number $retries" -Verbose
        $retries++
        Start-Sleep -Seconds 30 
    }
} 
while ($retries -le $retryCount)


# Construct the agent folder under the specified drive.
$agentInstallationPath = Join-Path -Path ($driveLetter + ":") -ChildPath $agentName 
# Create the directory for this agent.
New-Item -ItemType Directory -Force -Path $agentInstallationPath 

# Create a folder for the build work
New-Item -ItemType Directory -Force -Path (Join-Path $agentInstallationPath $WorkFolder)


Write-Verbose "Extracting the zip file for the agent" -Verbose
$destShellFolder = (new-object -com shell.application).namespace("$agentInstallationPath")
$destShellFolder.CopyHere((new-object -com shell.application).namespace("$agentTempFolderName\agent.zip").Items(), 16)

# Removing the ZoneIdentifier from files downloaded from the internet so the plugins can be loaded
# Don't recurse down _work or _diag, those files are not blocked and cause the process to take much longer
Write-Verbose "Unblocking files" -Verbose
Get-ChildItem -Path $agentInstallationPath | Unblock-File | out-null
Get-ChildItem -Recurse -Path $agentInstallationPath\Agent | Unblock-File | out-null

# Retrieve the path to the VSTSAgent.exe file.
$agentExePath = [System.IO.Path]::Combine($agentInstallationPath, 'Agent', 'VSOAgent.exe')
Write-Verbose "Agent location = $agentExePath" -Verbose
if (![System.IO.File]::Exists($agentExePath))
{
    Write-Error "File not found: $agentExePath" -Verbose
    exit -1
}

# Call the agent with the configure command and all the options (this creates the settings file) without prompting
# the user or blocking the cmd execution

Write-Verbose "Configuring agent" -Verbose


# Set the current directory to the agent dedicated one previously created.
Push-Location -Path $agentInstallationPath
# The actual install of the agent. Using NetworkService as default service logon account, and some other values that could be turned into paramenters if needed 
&start cmd.exe "/k $agentExePath /configure /RunningAsService /login:$vstsUser,$vstsUserPassword /serverUrl:$serverUrl ""/WindowsServiceLogonAccount:NT AUTHORITY\NetworkService"" /WindowsServiceLogonPassword /WindowsServiceDisplayName:VSTSBuildAgent /name:$agentName /poolname:$poolname /WorkFolder:$WorkFolder /StartMode:Automatic /force /NoPrompt &exit"

if ($LASTEXITCODE -ne 0)
{
    Write-Error "VSTS agent failed to configure."
    exit $LASTEXITCODE
}

# Restore original current directory.
Pop-Location

Write-Verbose "Agent install output: $LASTEXITCODE" -Verbose

Write-Verbose "Exiting vsts-agent-install.ps1" -Verbose