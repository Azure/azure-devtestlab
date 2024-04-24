[CmdletBinding()]
param(
    [Parameter(Mandatory, ParameterSetName='NoLogging')]
    [Parameter(Mandatory, ParameterSetName='UploadLogAccessToken')]
    [Parameter(Mandatory, ParameterSetName='UploadLogManagedIdentity')]
    [ValidateNotNullOrEmpty()]
    [string]
    $ScriptPath,

    [Parameter(ParameterSetName='NoLogging')]
    [Parameter(ParameterSetName='UploadLogAccessToken')]
    [Parameter(ParameterSetName='UploadLogManagedIdentity')]
    [string]
    $ScriptParameters = "",

    [Parameter(ParameterSetName='NoLogging')]
    [Parameter(ParameterSetName='UploadLogAccessToken')]
    [Parameter(ParameterSetName='UploadLogManagedIdentity')]
    [hashtable]
    $EnvironmentVariables = @{},

    [Parameter(ParameterSetName='NoLogging')]
    [Parameter(ParameterSetName='UploadLogAccessToken')]
    [Parameter(ParameterSetName='UploadLogManagedIdentity')]
    [ValidateNotNullOrEmpty()]
    [System.IO.DirectoryInfo]
    $LogsDirectory = "$env:SystemDrive\DevTestLabs\Artifacts\Logs",

    # Logs drop service URL
    [Parameter(Mandatory, ParameterSetName='UploadLogAccessToken')]
    [Parameter(Mandatory, ParameterSetName='UploadLogManagedIdentity')]
    [ValidateNotNullOrEmpty()]
    [uri]
    $LogsDropServiceURL,

    # Logs drop name
    [Parameter(Mandatory, ParameterSetName='UploadLogAccessToken')]
    [Parameter(Mandatory, ParameterSetName='UploadLogManagedIdentity')]
    [ValidateNotNullOrEmpty()]
    [string]
    $LogsDropName,

    # File globs relative to the root directory and separated by ';' that specify files to upload to the logs drop at the end of artifact execution.
    [Parameter(ParameterSetName='UploadLogAccessToken')]
    [Parameter(ParameterSetName='UploadLogManagedIdentity')]
    [string]
    $LogsDropFilesToInclude,

    # File globs relative to the root directory and separated by ';' that specify files to NOT upload to the logs drop at the end of the artifact execution.
    [Parameter(ParameterSetName='UploadLogAccessToken')]
    [Parameter(ParameterSetName='UploadLogManagedIdentity')]
    [string]
    $LogsDropFilesToExclude,

    # Required scopes for this access token:
    # - vso.drop_write: Upload logs to Azure Artifacts Drops in the $LogsDropServiceURL account
    [Parameter(Mandatory, ParameterSetName='UploadLogAccessToken')]
    [ValidateNotNullOrEmpty()]
    [securestring]
    $LogsDropServiceAccessToken,

    # Client ID for the managed identity that will be used to authenticate with the $LogsDropServiceURL account
    [Parameter(Mandatory, ParameterSetName='UploadLogManagedIdentity')]
    [ValidateNotNullOrEmpty()]
    [string]
    $LogsDropServiceManagedIdentityClientID,

    # Whether to ignore pending reboots from previous artifacts.
    [Parameter(ParameterSetName='NoLogging')]
    [Parameter(ParameterSetName='UploadLogAccessToken')]
    [Parameter(ParameterSetName='UploadLogManagedIdentity')]
    [switch]
    $IgnorePendingReboot
)

Import-Module (Join-Path $PSScriptRoot 'Common.psm1')

$logFileName = "$(Get-Date -Format FileDateTimeUniversal)-$(Split-Path -Path $ScriptPath -Leaf).log"
$logFile = [System.IO.FileInfo](Join-Path $LogsDirectory $logFileName)
Start-ArtifactLogging -LogFile $logFile

try {
    try {
        Initialize-Artifact

        if (Test-RebootPending) {
            if ($IgnorePendingReboot) {
                Write-Warning 'There is a reboot pending for this machine, but this artifact has been configured to ignore it.'
            }
            else {
                throw 'This artifact failed because there is a reboot pending for this machine. To fix this problem, add an artifact prior to this one that reboots the machine.'
            }
        }

        $script = Resolve-Path -Path $ScriptPath
        Write-Verbose "Script path resolved to '$script'."

        Write-Verbose "Attempting to set $($EnvironmentVariables.Keys.Count) environment variables..."
        $EnvironmentVariables.Keys | ForEach-Object { Set-Item -Path Env:$_ -Value $EnvironmentVariables.Item($_) }
        Write-Information "Successfully set $($EnvironmentVariables.Keys.Count) environment variables."

        # Before potentially logging secrets, check if there are any and replace them
        $scriptParamsForLogs = $ScriptParameters -replace "(ConvertTo-SecureString\s+)([^\s]+)(\s+-AsPlainText)",'$1***$3'

        Write-Verbose "Attempting to execute the script '$script' with parameters '$scriptParamsForLogs'..."
        Invoke-Command -ScriptBlock {Invoke-Expression ". `"$script`" $ScriptParameters"}
        Write-Information "Successfully executed script '$script'."
    } 
    catch {
        if ($PsCmdlet.ParameterSetName.StartsWith('UploadLog')) {
            Write-ErrorToArtifactOrchestrator -Message "$ScriptPath Failed: View '$logFileName' at log drop $(Format-AzureArtifactsLogsDropBrowserURL -LogsDropServiceURL $LogsDropServiceURL -LogsDropName $LogsDropName)"
        }
        throw
    }
    finally {
        Stop-ArtifactLogging -LogFile $logFile

        if ($PsCmdlet.ParameterSetName.StartsWith('UploadLog')) {
            if ($LogsDropFilesToInclude -and $LogsDropFilesToExclude) {
                New-FilesSnapshot -IncludeGlobPatterns $LogsDropFilesToInclude -ExcludeGlobPatterns $LogsDropFilesToExclude -SearchDirectory '/' -SnapshotDestinationDirectory $LogsDirectory -SnapshotName "Snapshot-$(Get-Date -Format FileDateTimeUniversal)"
            }
            elseif ($LogsDropFilesToInclude) {
                New-FilesSnapshot -IncludeGlobPatterns $LogsDropFilesToInclude -SearchDirectory '/' -SnapshotDestinationDirectory $LogsDirectory -SnapshotName "Snapshot-$(Get-Date -Format FileDateTimeUniversal)"
            }
        
            if ($PsCmdlet.ParameterSetName.EndsWith('ManagedIdentity')) {
                $LogsDropServiceAccessToken = Get-AccessTokenUsingManagedIdentity -ClientID $LogsDropServiceManagedIdentityClientID
            }
            Publish-ArtifactLogs -LogsDropServiceURL $LogsDropServiceURL -LogsDropName $LogsDropName -LogsDirectory $LogsDirectory -AccessToken $LogsDropServiceAccessToken
        }
    }
}
catch {

    if ($PsCmdlet.ParameterSetName.StartsWith('UploadLog')) {
        if ($PsCmdlet.ParameterSetName.EndsWith('ManagedIdentity')) {
            $LogsDropServiceAccessToken = Get-AccessTokenUsingManagedIdentity -ClientID $LogsDropServiceManagedIdentityClientID
        }
        Complete-ArtifactLogsDrop -LogsDropServiceURL $LogsDropServiceURL -LogsDropName $LogsDropName -AccessToken $LogsDropServiceAccessToken
    }

    throw
}