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

if ($driveLetter.length -ne 1)
{
    Write-Error "The drive letter must be 1 character only; exiting."
    exit -1
}

if ($vstsAccount -match "https*://" -or $vstsAccount -match "visualstudio.com")
{
    Write-Error "VSTS account should not be the URL, just the account name."
    exit -1
}

$vstsUser = "AzureDevTestLabs"

$currentLocation = Split-Path -parent $MyInvocation.MyCommand.Definition

# Create a temporary directory to download from VSTS the agent package (agent.zip) to, and then launch the configuration.
$agentTempFolderName = Join-Path $env:temp ([System.IO.Path]::GetRandomFileName())
New-Item -ItemType Directory -Force -Path $agentTempFolderName

$serverUrl = "https://$vstsAccount.visualstudio.com"

$vstsAgentUrl = "$serverUrl/_apis/distributedtask/packages/agent"

$retryCount = 3
$retries = 1
do
{
    try
    {
        $basicAuth = ("{0}:{1}" -f $vstsUser, $vstsUserPassword) 
        $basicAuth = [System.Text.Encoding]::UTF8.GetBytes($basicAuth)
        $basicAuth = [System.Convert]::ToBase64String($basicAuth)
        $headers = @{ Authorization = ("Basic {0}" -f $basicAuth) }

        Invoke-WebRequest -Uri $vstsAgentUrl -headers $headers -Method Get -OutFile "$agentTempFolderName\agent.zip"
        break
    }
    catch
    {
        $exceptionText = ($_ | Out-String).Trim()
        $retries++
        
        if ($retries -ge $retryCount)
        {
            Write-Error "Failed to download agent due to $exceptionText"
            exit -1
        }
        
        Start-Sleep -Seconds 30 
    }
} 
while ($retries -le $retryCount)


# Construct the agent folder under the specified drive.
$installPathDir = $driveLetter + ":"
try
{
    $agentInstallationPath = Join-Path -Path $installPathDir -ChildPath $agentName -ErrorAction "Stop"
}
catch
{
    Write-Error "Failed to create the agent directory at $installPathDir."
    exit -1
}

# Create the directory for this agent.
New-Item -ItemType Directory -Force -Path $agentInstallationPath 

# Create a folder for the build work
New-Item -ItemType Directory -Force -Path (Join-Path $agentInstallationPath $WorkFolder)

$destShellFolder = (new-object -com shell.application).namespace("$agentInstallationPath")
$destShellFolder.CopyHere((new-object -com shell.application).namespace("$agentTempFolderName\agent.zip").Items(), 16)

# Removing the ZoneIdentifier from files downloaded from the internet so the plugins can be loaded
# Don't recurse down _work or _diag, those files are not blocked and cause the process to take much longer
Get-ChildItem -Path $agentInstallationPath | Unblock-File | out-null
Get-ChildItem -Recurse -Path $agentInstallationPath\Agent | Unblock-File | out-null

# Retrieve the path to the VSTSAgent.exe file.
$agentExePath = [System.IO.Path]::Combine($agentInstallationPath, 'Agent', 'VSOAgent.exe')
if (![System.IO.File]::Exists($agentExePath))
{
    Write-Error "File not found: $agentExePath" -Verbose
    exit -1
}

# Call the agent with the configure command and all the options (this creates the settings file) without prompting
# the user or blocking the cmd execution

# Set the current directory to the agent dedicated one previously created.
Push-Location -Path $agentInstallationPath
# The actual install of the agent. Using NetworkService as default service logon account, and some other values that could be turned into paramenters if needed 
&start cmd.exe "/k $agentExePath /configure /RunningAsService /login:$vstsUser,$vstsUserPassword /serverUrl:$serverUrl ""/WindowsServiceLogonAccount:NT AUTHORITY\NetworkService"" /WindowsServiceLogonPassword /WindowsServiceDisplayName:VSTSBuildAgent /name:$agentName /poolname:$poolname /WorkFolder:$WorkFolder /StartMode:Automatic /force /NoPrompt &exit"

if ($LASTEXITCODE -ne 0)
{
    Write-Error "VSTS agent failed to configure. Exit code was $LASTEXITCODE."
    exit $LASTEXITCODE
}

# Restore original current directory.
Pop-Location

Write-Host "Agent install output: $LASTEXITCODE" -Verbose