# Downloads the Azure DevOps Pipelines Agent and installs specified instances on the new machine
# under C:\agents\ and registers with the Azure DevOps Pipelines agent pool

# Enable -Verbose option
[CmdletBinding()]
Param
(
	[Parameter(Mandatory=$true)]
	[string]$Account,

	[Parameter(Mandatory=$true)]
	[String]$PersonalAccessToken,

	[string]$AgentName = $env:COMPUTERNAME,

	[string]$AgentNamePrefix= "dtl",

	[Parameter(Mandatory=$true)]
	[string]$PoolName,

	[Parameter(Mandatory=$true)]
	[int]$AgentCount
)

Write-Verbose "Entering powershell task" -verbose

$currentLocation = Split-Path -parent $MyInvocation.MyCommand.Definition
Write-Verbose "Current folder: $currentLocation" -verbose

#Create a temporary directory where to download from VSTS the agent package (vsts-agent.zip) and then launch the configuration.
$agentTempFolderName = Join-Path $env:temp ([System.IO.Path]::GetRandomFileName())
New-Item -ItemType Directory -Force -Path $agentTempFolderName
Write-Verbose "Temporary Agent download folder: $agentTempFolderName" -verbose

$serverUrl = "https://dev.azure.com/$Account"
Write-Verbose "Server URL: $serverUrl" -verbose

$retryCount = 3
$retries = 1
Write-Verbose "Downloading Agent install files" -verbose
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
do
{
  try
  {
    Write-Verbose "Trying to get download URL for latest VSTS agent release..."
    $vstsAgentUrl = "$serverUrl/_apis/distributedtask/packages/agent/win7-x64?`$top=1&api-version=3.0"
    $basicAuth = (":{0}" -f  $PersonalAccessToken)
    $basicAuth = [System.Text.Encoding]::UTF8.GetBytes($basicAuth)
    $basicAuth = [System.Convert]::ToBase64String($basicAuth)
    $headers = @{ Authorization = ("Basic {0}" -f $basicAuth) }
    $agentList = Invoke-WebRequest -Uri $vstsAgentUrl -Headers $headers -Method Get -ContentType application/json -UseBasicParsing | ConvertFrom-Json
    $agent = $agentList.value
    if ($agent -is [Array])
    {
        $agent = $agentList.value[0]
    }
    $agentPackagePath = "$agentTempFolderName\agent.zip"

    Invoke-WebRequest -Uri $agent.downloadUrl -Headers $headers -Method Get -OutFile  "$agentPackagePath" -UseBasicParsing | Out-Null

    Write-Verbose "Downloaded agent successfully on attempt $retries" -verbose
    break
  }
  catch
  {
    $exceptionText = ($_ | Out-String).Trim()
    Write-Verbose "Exception occured downloading agent: $exceptionText in try number $retries" -verbose
    $retries++
    Start-Sleep -Seconds 30 
  }
} 
while ($retries -le $retryCount)

if([string]::IsNullOrWhiteSpace($AgentName)){
	$AgentName = $env:COMPUTERNAME
}

$AgentName =("{0}-{1}" -f $AgentNamePrefix, $AgentName)

for ($i=1; $i -lt $AgentCount+1; $i++)
{
	$Agent = ($AgentName + "-" + $i)

	# Construct the agent folder under the main (hardcoded) C: drive.
	$agentInstallationPath = Join-Path "C:\agents" $Agent

	# Create the directory for this agent.
	New-Item -ItemType Directory -Force -Path $agentInstallationPath

	# Set the current directory to the agent dedicated one previously created.
	Push-Location -Path $agentInstallationPath
	
	Write-Verbose "Extracting the zip file for the agent" -verbose
	$destShellFolder = (new-object -com shell.application).namespace("$agentInstallationPath")
	$destShellFolder.CopyHere((new-object -com shell.application).namespace("$agentTempFolderName\agent.zip").Items(),16)

	# Removing the ZoneIdentifier from files downloaded from the internet so the plugins can be loaded
	# Don't recurse down _work or _diag, those files are not blocked and cause the process to take much longer
	Write-Verbose "Unblocking files" -verbose
	Get-ChildItem -Recurse -Path $agentInstallationPath | Unblock-File | out-null

	# Retrieve the path to the config.cmd file.
	$agentConfigPath = [System.IO.Path]::Combine($agentInstallationPath, 'config.cmd')
	Write-Verbose "Agent Location = $agentConfigPath" -Verbose
	if (![System.IO.File]::Exists($agentConfigPath))
	{
		Write-Error "File not found: $agentConfigPath" -Verbose
		return
	}

	# Call the agent with the configure command and all the options (this creates the settings file) without prompting
	# the user or blocking the cmd execution
	Write-Verbose "Configuring agent '$($Agent)'" -Verbose		
	.\config.cmd --unattended --url $serverUrl --auth PAT --token $PersonalAccessToken --pool $PoolName --agent $Agent --runasservice
	
	Write-Verbose "Agent install output: $LASTEXITCODE" -Verbose
	
	Pop-Location
}

Write-Verbose "Exiting InstallVSTSAgent.ps1" -Verbose