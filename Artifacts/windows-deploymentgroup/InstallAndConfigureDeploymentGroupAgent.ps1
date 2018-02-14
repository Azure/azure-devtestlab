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
    If(-NOT ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole] "Administrator"))
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

function Prep-MachineForAutoLogon
{
    [CmdletBinding()]
    param(
        [Parameter(Mandatory=$false)][String][AllowEmptyString()] $windowsLogonAccount,
        [Parameter(Mandatory=$false)][String][AllowEmptyString()] $windowsLogonPassword
    )

    $ErrorActionPreference = "Stop"
    
    if ([string]::IsNullOrWhiteSpace($windowsLogonPassword))
    {
        Write-Error "Windows logon password was not provided. Please retry by providing a valid windows logon password to enable autologon."
    }

    # Create a PS session for the user to trigger the creation of the registry entries required for autologon
    $computerName = "localhost"
    $password = ConvertTo-SecureString $windowsLogonPassword -AsPlainText -Force

    if ($windowsLogonAccount.Split("\").Count -eq 2)
    {
        $domain = $windowsLogonAccount.Split("\")[0]
        $userName = $windowsLogonAccount.Split('\')[1]
    }
    else
    {
        $domain = $Env:ComputerName
        $userName = $windowsLogonAccount
    }

    $credentials = New-Object System.Management.Automation.PSCredential("$domain\\$userName", $password)
    Enter-PSSession -ComputerName $computerName -Credential $credentials
    Exit-PSSession

    try
    {
        # Check if the HKU drive already exists
        Get-PSDrive -PSProvider Registry -Name HKU | Out-Null
        $canCheckRegistry = $true
    }
    catch [System.Management.Automation.DriveNotFoundException]
    {
        try 
        {
            # Create the HKU drive
            New-PSDrive -PSProvider Registry -Name HKU -Root HKEY_USERS | Out-Null
            $canCheckRegistry = $true
        }
        catch 
        {
            # Ignore the failure to create the drive and go ahead with trying to set the agent up
            Write-Warning "Moving ahead with agent setup as the script failed to create HKU drive necessary for checking if the registry entry for the user's SId exists.\n$_"
        }
    }

    # 120 seconds timeout
    $timeout = 120

    # Check if the registry key required for enabling autologon is present on the machine, if not wait for 120 seconds in case the user profile is still getting created
    while ($timeout -ge 0 -and $canCheckRegistry)
    {
        $objUser = New-Object System.Security.Principal.NTAccount($windowsLogonAccount)
        $securityId = $objUser.Translate([System.Security.Principal.SecurityIdentifier])
        $securityId = $securityId.Value

        if (Test-Path "HKU:\\$securityId")
        {
            if (!(Test-Path "HKU:\\$securityId\\SOFTWARE\\Microsoft\\Windows\\CurrentVersion\\Run"))
            {
                New-Item -Path "HKU:\\$securityId\\SOFTWARE\\Microsoft\\Windows\\CurrentVersion\\Run" -Force
                Write-Host "Created the registry entry path required to enable autologon."
            }
        
            break
        }
        else
        {
            $timeout -= 10
            Start-Sleep(10)
        }
    }

    if ($timeout -lt 0)
    {
        Write-Warning "Failed to find the registry entry for the SId of the user, this is required to enable autologon. Trying to start the agent anyway."
    }
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
        Prep-MachineForAutoLogon -windowsLogonAccount $windowsLogonAccount -windowsLogonPassword $windowsLogonPassword

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








