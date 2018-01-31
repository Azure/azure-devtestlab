param (
    [Parameter(Mandatory=$true)] $accountUrl,
    [Parameter(Mandatory=$true)] $projectName,
    [Parameter(Mandatory=$true)] $deploymentGroupName,
    [Parameter(Mandatory=$true)] $personalAccessToken,
    [Parameter(Mandatory=$true)][Boolean] $runAsAutoLogon,
    [Parameter(Mandatory=$false)][String][AllowEmptyString()] $deploymentAgentTags,
    [Parameter(Mandatory=$false)][String][AllowEmptyString()] $agentInstallPath,
    [Parameter(Mandatory=$false)][String][AllowEmptyString()] $agentName,
    [Parameter(Mandatory=$false)][String][AllowEmptyString()] $windowsLogonAccount,
    [Parameter(Mandatory=$false)][String][AllowEmptyString()] $windowsLogonPassword
)

function Test-InstallPrerequisites
{
    If(-NOT ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole] “Administrator”))
    { 
        Write-Host "Insufficient privileges. Run command in Administrator PowerShell Prompt"
        Exit -1
    }
}

function New-AgentPath 
{
    [CmdletBinding()]
    param([Parameter(Mandatory=$false)] [String] [AllowEmptyString()]$agentInstallPath)

    If ([string]::IsNullOrEmpty($agentInstallPath))
    {
        $agentInstallPath = "$env:SystemDrive\vstsagent"
    }
    
    If (-NOT (Test-Path "$agentInstallPath"))
    {
        New-Item -ItemType Directory -Path $agentInstallPath -Force | Out-Null

        #Wait Until directory reflects in file system
        $Stoploop = $false
        [int]$Retrycount = 0

        do {
            try {
                pushd $agentInstallPath
                popd
                $Stoploop = $true
            } catch {
                if ($Retrycount -gt 3) 
                {
                    $Stoploop = $true
                    Write-Host "Cannot find directory: $agentInstallPath"
                    Exit -1
                } else {
                    Write-Verbose "Wait for directory creation. Retrying in 30 seconds..."
                    Start-Sleep -Seconds 30
                    $Retrycount = $Retrycount + 1
                }
            }
        } While ($Stoploop -eq $false)
    }

    Write-Host "Created deployment agent install directory: $agentInstallPath"
    return $agentInstallPath
}

function Get-DeploymentAgentDownloadUrl
{
    [CmdletBinding()]
    param(
        [Parameter(Mandatory=$true)]$accountUrl,
        [Parameter(Mandatory=$true)]$personalAccessToken
        )

    $platform = "win7-x64"
    $downloadAPIVersion = "3.0-preview.2"
    $userName = "AzureDevTestLabs"

    [string] $restCallUrl = $accountUrl + ("/_apis/distributedtask/packages/agent/{0}?top=1&api-version={1}" -f $platform,$downloadAPIVersion)
    Write-Host "Agent Download REST url: $restCallUrl"

    
    $basicAuth = ("{0}:{1}" -f $userName, $personalAccessToken)
    $basicAuth = [System.Text.Encoding]::UTF8.GetBytes($basicAuth)
    $basicAuth = [System.Convert]::ToBase64String($basicAuth)
    $headers = @{Authorization=("Basic {0}" -f $basicAuth)}

    $response = Invoke-RestMethod -Uri $restCallUrl -headers $headers -Method Get -ContentType 'application/json'
    Write-Host "Agent Download REST response: $response"
    
    $downloadUrl = $response.Value[0].downloadUrl
    Write-Host "Deployment Agent download url: $downloadUrl"

    return $downloadUrl
}

function Download-DeploymentGroupAgent
{
    [CmdletBinding()]
    param(
        [Parameter(Mandatory=$true)]$accountUrl,
        [Parameter(Mandatory=$true)]$personalAccessToken,
        [Parameter(Mandatory=$true)]$agentInstallPath,
        [Parameter(Mandatory=$true)]$agentZipFile
        )
   
    $agentZip="$agentInstallPath\$agentZipFile";
    $downloadUrl = Get-DeploymentAgentDownloadUrl $accountUrl $personalAccessToken
    pushd $agentInstallPath

    #download
    Write-Host "Begin Agent download"
    (New-Object Net.WebClient).DownloadFile($downloadUrl, $agentZip);
    Write-Host "Agent download complete"

    #extract
    Add-Type -AssemblyName System.IO.Compression.FileSystem;[System.IO.Compression.ZipFile]::ExtractToDirectory($agentZip, "$agentInstallPath");
    Write-Host "Agent zip exacted in install directory: $agentInstallPath"

    popd
}

function Configure-DeploymentGroupAgent
{
    [CmdletBinding()]
    param(
        [Parameter(Mandatory=$true)] $accountUrl,
        [Parameter(Mandatory=$true)] $projectName,
        [Parameter(Mandatory=$true)] $deploymentGroupName,
        [Parameter(Mandatory=$true)] $personalAccessToken,
        [Parameter(Mandatory=$false)][String][AllowEmptyString()] $agentName,
        [Parameter(Mandatory=$true)] $agentInstallPath,
        [Parameter(Mandatory=$false)][String][AllowEmptyString()] $deploymentAgentTags,
        [Parameter(Mandatory=$true)][Boolean] $runAsAutoLogon,
        [Parameter(Mandatory=$false)][String][AllowEmptyString()] $windowsLogonAccount,
        [Parameter(Mandatory=$false)][String][AllowEmptyString()] $windowsLogonPassword
        )

    If ([string]::IsNullOrEmpty($agentName))
    {
        $agentName = "$env:COMPUTERNAME"
    }
    Write-Host "Configuring Agent: $agentName"

    pushd $agentInstallPath

    if ($runAsAutoLogon)
    {
        # Arguements to run agent with autologon enabled
        $agentConfigArgs = "--unattended", "--url", $accountUrl, "--auth", "PAT", "--token", $personalAccessToken, "--deploymentgroup", "--projectname", $projectName, "--deploymentgroupname", $deploymentGroupName, "--agent", $agentName, "--runAsAutoLogon", "--overwriteAutoLogon", "--windowslogonaccount", $windowsLogonAccount, "--work", "_work"
    }
    else
    {
        # Arguements to run agent as a service
        $agentConfigArgs = "--unattended", "--url", $accountUrl, "--auth", "PAT", "--token", $personalAccessToken, "--deploymentgroup", "--projectname", $projectName, "--deploymentgroupname", $deploymentGroupName, "--agent", $agentName, "--runasservice", "--windowslogonaccount", $windowsLogonAccount, "--work", "_work"
    }

    if (-not [string]::IsNullOrWhiteSpace($windowsLogonPassword))
    {
        $agentConfigArgs += "--windowslogonpassword", $windowsLogonPassword
    }
    if(-not [string]::IsNullOrWhiteSpace($deploymentAgentTags))
    {
        $agentConfigArgs += "--deploymentgrouptags", $deploymentAgentTags
    }

    & .\config.cmd $agentConfigArgs

    if (! $?) 
    {
        Write-Host "Deployment agent configuration failed."
        Exit 1
    }
    popd
}

function Remove-InstallFiles
{
    [CmdletBinding()]
    param(
        [Parameter(Mandatory=$true)]$agentInstallPath,
        [Parameter(Mandatory=$true)]$agentZipFile
        )

    pushd $agentInstallPath
    $agentZip="$agentInstallPath\$agentZipFile";
    Remove-Item $agentZip;
    popd
}

function Install-DeploymentGroupAgent 
{
    [CmdletBinding()]
    param(
        [Parameter(Mandatory=$true)] $accountUrl,
        [Parameter(Mandatory=$true)] $projectName,
        [Parameter(Mandatory=$true)] $deploymentGroupName,
        [Parameter(Mandatory=$true)] $personalAccessToken,
        [Parameter(Mandatory=$false)][String][AllowEmptyString()] $deploymentAgentTags,
        [Parameter(Mandatory=$false)][String][AllowEmptyString()] $agentInstallPath,
        [Parameter(Mandatory=$false)][String][AllowEmptyString()] $agentName,
        [Parameter(Mandatory=$true)][Boolean] $runAsAutoLogon,
        [Parameter(Mandatory=$false)][String][AllowEmptyString()] $windowsLogonAccount,
        [Parameter(Mandatory=$false)][String][AllowEmptyString()] $windowsLogonPassword
        )

    $ErrorActionPreference="Stop";

    $agentZipFile = "agent.zip"

    try 
    {

        #Initial checks
        Test-InstallPrerequisites
    
        #Create agent directory
        $agentInstallPath = New-AgentPath $agentInstallPath
    
        #Download Agent
        Download-DeploymentGroupAgent $accountUrl $personalAccessToken $agentInstallPath $agentZipFile

        #Configure Agent
        Configure-DeploymentGroupAgent $accountUrl $projectName $deploymentGroupName $personalAccessToken $agentName $agentInstallPath $deploymentAgentTags $runAsAutoLogon $windowsLogonAccount $windowsLogonPassword

        #Cleanup
        Remove-InstallFiles $agentInstallPath $agentZipFile

    } catch {

        if (($null -ne $Error[0]) -and ($null -ne $Error[0].Exception))
        {
            if ($null -ne $Error[0].Exception.Message)
            {
                Write-Host $Error[0].Exception.Message
            } else {
                Write-Host $Error[0].Exception
            }
        }
        Exit -1

    }
}

Install-DeploymentGroupAgent $accountUrl $projectName $deploymentGroupName $personalAccessToken $deploymentAgentTags $agentInstallPath $agentName $runAsAutoLogon $windowsLogonAccount $windowsLogonPassword








