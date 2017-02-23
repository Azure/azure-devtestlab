# Downloads the Visual Studio Online Build Agent, installs on the new machine, registers with the Visual
# Studio Online account, and adds to the specified build agent pool

[CmdletBinding()]
Param(
    [Parameter(Mandatory=$true)]
    [ValidateNotNullOrEmpty()]
    $vstsAccount,
    
    [Parameter(Mandatory=$true)]
    [ValidateNotNullOrEmpty()]
    $vstsUserPassword,
    
    [Parameter(Mandatory=$true)]
    [ValidateNotNullOrEmpty()]
    $agentName,
    
    [Parameter(Mandatory=$true)]
    [ValidateNotNullOrEmpty()]
    $poolname,

    [Parameter(Mandatory=$true)]
    [ValidateNotNullOrEmpty()]
    $windowsLogonAccount,

    [Parameter(Mandatory=$true)]
    [AllowEmptyString()]
    $windowsLogonPassword,
    
    [Parameter(Mandatory=$true)]
    [ValidatePattern("[c-zC-Z]")]
    [ValidateLength(1, 1)]
    [String]$driveLetter,
    
    [Parameter(Mandatory=$true)]
    [AllowEmptyString()]
    $workDirectory
)

$ErrorActionPreference = "Stop"

trap
{
    $_ | Write-Error -ErrorAction Continue
    exit 1
}

if ($vstsAccount -match "https*://" -or $vstsAccount -match "visualstudio.com")
{
    Write-Error "VSTS account should not be the URL, just the account name."
}

if ($workDirectory -ne "" -and !(Test-Path -Path $workDirectory -IsValid -ErrorAction Ignore))
{
    Write-Error "Work Directory '$workDirectory' is not a valid path."
}

$currentLocation = Split-Path -parent $MyInvocation.MyCommand.Definition

# Create a temporary directory to download from VSTS the agent package (agent.zip) to, and then launch the configuration.
$agentTempFolderName = Join-Path $env:temp ([System.IO.Path]::GetRandomFileName())
New-Item -ItemType Directory -Force -Path $agentTempFolderName

$serverUrl = "https://$vstsAccount.visualstudio.com"
$vstsAgentUrl = $serverUrl + '/_apis/distributedtask/packages/agent/win7-x64?$top=1&api-version=3.0'
$vstsUser = "AzureDevTestLabs"

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

        $agentList = Invoke-RestMethod -Uri $vstsAgentUrl -Headers $headers -Method Get -ContentType application/json
        $downloadUrl = $agentList.value[0].downloadUrl
        Invoke-WebRequest -Uri $downloadUrl -Headers $headers -Method Get -OutFile "$agentTempFolderName\agent.zip"
        break
    }
    catch
    {
        $exceptionText = ($_ | Out-String).Trim()
        $retries++
            
        if ($retries -ge $retryCount)
        {
            Write-Error "Failed to download agent due to $exceptionText"
        }
            
        Start-Sleep -Seconds 30 
    }
} 
while ($retries -le $retryCount)


# Construct the agent folder under the specified drive.
$installPathDir = $driveLetter + ":"
try
{
    $agentInstallationPath = Join-Path -Path $installPathDir -ChildPath $agentName
}
catch
{
    Write-Error "Failed to create the agent directory at $installPathDir."
}

# Create the directory for this agent.
New-Item -ItemType Directory -Force -Path $agentInstallationPath 

$destShellFolder = (new-object -com shell.application).namespace("$agentInstallationPath")
$destShellFolder.CopyHere((new-object -com shell.application).namespace("$agentTempFolderName\agent.zip").Items(), 16)

# Retrieve the path to the VSTSAgent.exe file.
$agentExePath = [System.IO.Path]::Combine($agentInstallationPath, 'config.cmd')
if (![System.IO.File]::Exists($agentExePath))
{
    Write-Error "File not found: $agentExePath"
}

# Call the agent with the configure command and all the options (this creates the settings file) without prompting
# the user or blocking the cmd execution

# Set the current directory to the agent dedicated one previously created.
Push-Location -Path $agentInstallationPath
# The actual install of the agent. Using --runasservice, and some other values that could be turned into paramenters if needed.
$agentConfigArgs = "--unattended", "--url", $serverUrl, "--auth", "PAT", "--token", $vstsUserPassword, "--pool", $poolname, "--agent", $agentName, "--runasservice", "--windowslogonaccount", $windowsLogonAccount
if ($windowsLogonPassword -ne "")
{
    $agentConfigArgs += "--windowslogonpassword", $windowsLogonPassword
}
if ($workDirectory -ne "")
{
    $agentConfigArgs += "--work", $workDirectory
}
& $agentExePath $agentConfigArgs
if ($LASTEXITCODE -ne 0)
{
    Write-Error "Agent configuration failed with exit code: $LASTEXITCODE"
}

# Restore original current directory.
Pop-Location
    
exit 0
