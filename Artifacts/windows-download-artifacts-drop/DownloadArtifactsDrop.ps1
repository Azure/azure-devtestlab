[CmdletBinding()]
param(
    # Azure Devops account URL that contains the drop to download
    [Parameter(Mandatory, ParameterSetName='DownloadDropAccessToken_UploadLogAccessToken')]
    [Parameter(Mandatory, ParameterSetName='DownloadDropAccessToken_UploadLogManagedIdentity')]
    [Parameter(Mandatory, ParameterSetName='DownloadDropAccessToken_NoLogging')]
    [Parameter(Mandatory, ParameterSetName='DownloadDropManagedIdentity_UploadLogAccessToken')]
    [Parameter(Mandatory, ParameterSetName='DownloadDropManagedIdentity_UploadLogManagedIdentity')]
    [Parameter(Mandatory, ParameterSetName='DownloadDropManagedIdentity_NoLogging')]
    [ValidateNotNullOrEmpty()]
    [uri]
    $AccountURL,

    # Name of the drop to download
    [Parameter(Mandatory, ParameterSetName='DownloadDropAccessToken_UploadLogAccessToken')]
    [Parameter(Mandatory, ParameterSetName='DownloadDropAccessToken_UploadLogManagedIdentity')]
    [Parameter(Mandatory, ParameterSetName='DownloadDropAccessToken_NoLogging')]
    [Parameter(Mandatory, ParameterSetName='DownloadDropManagedIdentity_UploadLogAccessToken')]
    [Parameter(Mandatory, ParameterSetName='DownloadDropManagedIdentity_UploadLogManagedIdentity')]
    [Parameter(Mandatory, ParameterSetName='DownloadDropManagedIdentity_NoLogging')]
    [ValidateNotNullOrEmpty()]
    [string]
    $DropName,

    # Directory to download the drop to
    [Parameter(Mandatory, ParameterSetName='DownloadDropAccessToken_UploadLogAccessToken')]
    [Parameter(Mandatory, ParameterSetName='DownloadDropAccessToken_UploadLogManagedIdentity')]
    [Parameter(Mandatory, ParameterSetName='DownloadDropAccessToken_NoLogging')]
    [Parameter(Mandatory, ParameterSetName='DownloadDropManagedIdentity_UploadLogAccessToken')]
    [Parameter(Mandatory, ParameterSetName='DownloadDropManagedIdentity_UploadLogManagedIdentity')]
    [Parameter(Mandatory, ParameterSetName='DownloadDropManagedIdentity_NoLogging')]
    [ValidateNotNullOrEmpty()]
    [System.IO.DirectoryInfo]
    $DestinationDirectory,

    # Required scopes for this OAuth access token:
    # - vso.drop_read: Download artifacts drop in the $AccountURL account
    [Parameter(Mandatory, ParameterSetName='DownloadDropAccessToken_UploadLogAccessToken')]
    [Parameter(Mandatory, ParameterSetName='DownloadDropAccessToken_UploadLogManagedIdentity')]
    [Parameter(Mandatory, ParameterSetName='DownloadDropAccessToken_NoLogging')]
    [ValidateNotNullOrEmpty()]
    [securestring]
    $AccessToken,

    # Client ID of the managed identity to use to get an access token
    [Parameter(Mandatory, ParameterSetName='DownloadDropManagedIdentity_UploadLogAccessToken')]
    [Parameter(Mandatory, ParameterSetName='DownloadDropManagedIdentity_UploadLogManagedIdentity')]
    [Parameter(Mandatory, ParameterSetName='DownloadDropManagedIdentity_NoLogging')]
    [ValidateNotNullOrEmpty()]
    [string]
    $ManagedIdentityClientID,

    [Parameter(ParameterSetName='DownloadDropAccessToken_UploadLogAccessToken')]
    [Parameter(ParameterSetName='DownloadDropAccessToken_UploadLogManagedIdentity')]
    [Parameter(ParameterSetName='DownloadDropAccessToken_NoLogging')]
    [Parameter(ParameterSetName='DownloadDropManagedIdentity_UploadLogAccessToken')]
    [Parameter(ParameterSetName='DownloadDropManagedIdentity_UploadLogManagedIdentity')]
    [Parameter(ParameterSetName='DownloadDropManagedIdentity_NoLogging')]
    [ValidateNotNullOrEmpty()]
    [System.IO.DirectoryInfo]
    $LogsDirectory = "$env:SystemDrive\DevTestLabs\Artifacts\Logs",

    # Logs drop service URL
    [Parameter(Mandatory, ParameterSetName='DownloadDropAccessToken_UploadLogAccessToken')]
    [Parameter(Mandatory, ParameterSetName='DownloadDropAccessToken_UploadLogManagedIdentity')]
    [Parameter(Mandatory, ParameterSetName='DownloadDropManagedIdentity_UploadLogAccessToken')]
    [Parameter(Mandatory, ParameterSetName='DownloadDropManagedIdentity_UploadLogManagedIdentity')]
    [ValidateNotNullOrEmpty()]
    [uri]
    $LogsDropServiceURL,

    # Logs drop name
    [Parameter(Mandatory, ParameterSetName='DownloadDropAccessToken_UploadLogAccessToken')]
    [Parameter(Mandatory, ParameterSetName='DownloadDropAccessToken_UploadLogManagedIdentity')]
    [Parameter(Mandatory, ParameterSetName='DownloadDropManagedIdentity_UploadLogAccessToken')]
    [Parameter(Mandatory, ParameterSetName='DownloadDropManagedIdentity_UploadLogManagedIdentity')]
    [ValidateNotNullOrEmpty()]
    [string]
    $LogsDropName,

    # File globs relative to the root directory and separated by ';' that specify files to upload to the logs drop at the end of artifact execution.
    [Parameter(ParameterSetName='DownloadDropAccessToken_UploadLogAccessToken')]
    [Parameter(ParameterSetName='DownloadDropAccessToken_UploadLogManagedIdentity')]
    [Parameter(ParameterSetName='DownloadDropManagedIdentity_UploadLogAccessToken')]
    [Parameter(ParameterSetName='DownloadDropManagedIdentity_UploadLogManagedIdentity')]
    [string]
    $LogsDropFilesToInclude,

    # File globs relative to the root directory and separated by ';' that specify files to NOT upload to the logs drop at the end of the artifact execution.
    [Parameter(ParameterSetName='DownloadDropAccessToken_UploadLogAccessToken')]
    [Parameter(ParameterSetName='DownloadDropAccessToken_UploadLogManagedIdentity')]
    [Parameter(ParameterSetName='DownloadDropManagedIdentity_UploadLogAccessToken')]
    [Parameter(ParameterSetName='DownloadDropManagedIdentity_UploadLogManagedIdentity')]
    [string]
    $LogsDropFilesToExclude,

    # Required scopes for this access token:
    # - vso.drop_write + vso.drop_manage: Upload logs to Azure Artifacts Drops in the $LogsDropServiceURL account
    [Parameter(Mandatory, ParameterSetName='DownloadDropAccessToken_UploadLogAccessToken')]
    [Parameter(Mandatory, ParameterSetName='DownloadDropManagedIdentity_UploadLogAccessToken')]
    [ValidateNotNullOrEmpty()]
    [securestring]
    $LogsDropServiceAccessToken,

    # Client ID for the managed identity that will be used to authenticate with the $LogsDropServiceURL account
    [Parameter(Mandatory, ParameterSetName='DownloadDropAccessToken_UploadLogManagedIdentity')]
    [Parameter(Mandatory, ParameterSetName='DownloadDropManagedIdentity_UploadLogManagedIdentity')]
    [ValidateNotNullOrEmpty()]
    [string]
    $LogsDropServiceManagedIdentityClientID,

    # Whether to ignore pending reboots from previous artifacts.
    [Parameter(Mandatory, ParameterSetName='DownloadDropAccessToken_UploadLogAccessToken')]
    [Parameter(Mandatory, ParameterSetName='DownloadDropAccessToken_UploadLogManagedIdentity')]
    [Parameter(Mandatory, ParameterSetName='DownloadDropAccessToken_NoLogging')]
    [Parameter(Mandatory, ParameterSetName='DownloadDropManagedIdentity_UploadLogAccessToken')]
    [Parameter(Mandatory, ParameterSetName='DownloadDropManagedIdentity_UploadLogManagedIdentity')]
    [Parameter(Mandatory, ParameterSetName='DownloadDropManagedIdentity_NoLogging')]
    [switch]
    $IgnorePendingReboot
)

Import-Module (Join-Path $PSScriptRoot 'Common.psm1')

$logFileName = "$(Get-Date -Format FileDateTimeUniversal)-DownloadArtifactsDrop.log"
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

        if (-not (Test-Path -Path $DestinationDirectory -PathType Container)) {
            New-Item -Path $DestinationDirectory -ItemType Directory -Force | Out-Null
        }

        $dropExeLogPath = Join-Path $LogsDirectory "$(Get-Date -Format FileDateTimeUniversal)-drop.exe.log"
        Write-Verbose "Attempting to download artifact drop '$DropName' to '$DestinationDirectory'..."

        if ($PsCmdlet.ParameterSetName.StartsWith('DownloadDropAccessToken')) {
            Install-AzureArtifactsDrop -DropServiceURL $AccountUrl -DropName $DropName -DestinationDirectory $DestinationDirectory -TraceTo $dropExeLogPath -AccessToken $AccessToken
        }
        elseif ($PsCmdlet.ParameterSetName.StartsWith('DownloadDropManagedIdentity')) {
            Install-AzureArtifactsDrop -DropServiceURL $AccountUrl -DropName $DropName -DestinationDirectory $DestinationDirectory -TraceTo $dropExeLogPath -AccessToken (Get-AccessTokenUsingManagedIdentity -ClientID $ManagedIdentityClientID)
        }
        else {
            throw "The parameters set '$($PsCmdlet.ParameterSetName)' is not supported."
        }

        Write-Information "Successfully downloaded artifact drop '$DropName' to '$DestinationDirectory'."
    }
    catch {
        if (-not $PsCmdlet.ParameterSetName.EndsWith('NoLogging')) {
                Write-ErrorToArtifactOrchestrator -Message "$ScriptPath Failed: View '$logFileName' at log drop $(Format-AzureArtifactsLogsDropBrowserURL -LogsDropServiceURL $LogsDropServiceURL -LogsDropName $LogsDropName)"
        }
        throw
    } 
    finally {
        Stop-ArtifactLogging -LogFile $logFile

        if (-not $PsCmdlet.ParameterSetName.EndsWith('NoLogging')) {
            if ($LogsDropFilesToInclude -and $LogsDropFilesToExclude) {
                New-FilesSnapshot -IncludeGlobPatterns $LogsDropFilesToInclude -ExcludeGlobPatterns $LogsDropFilesToExclude -SearchDirectory '/' -SnapshotDestinationDirectory $LogsDirectory -SnapshotName "Snapshot-$(Get-Date -Format FileDateTimeUniversal)"
            }
            elseif ($LogsDropFilesToInclude) {
                New-FilesSnapshot -IncludeGlobPatterns $LogsDropFilesToInclude -SearchDirectory '/' -SnapshotDestinationDirectory $LogsDirectory -SnapshotName "Snapshot-$(Get-Date -Format FileDateTimeUniversal)"
            }

            if ($PsCmdlet.ParameterSetName.EndsWith('UploadLogManagedIdentity')) {
                $LogsDropServiceAccessToken = Get-AccessTokenUsingManagedIdentity -ClientID $LogsDropServiceManagedIdentityClientID
            }
            Publish-ArtifactLogs -LogsDropServiceURL $LogsDropServiceURL -LogsDropName $LogsDropName -LogsDirectory $LogsDirectory -AccessToken $LogsDropServiceAccessToken
        }
    }
}
catch {
    if (-not $PsCmdlet.ParameterSetName.EndsWith('NoLogging')) {
        if ($PsCmdlet.ParameterSetName.EndsWith('UploadLogManagedIdentity')) {
            $LogsDropServiceAccessToken = Get-AccessTokenUsingManagedIdentity -ClientID $LogsDropServiceManagedIdentityClientID
        }
        Complete-ArtifactLogsDrop -LogsDropServiceURL $LogsDropServiceURL -LogsDropName $LogsDropName -AccessToken $LogsDropServiceAccessToken
    }
    throw
}