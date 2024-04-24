function Add-DirectoryToAzureArtifactsDrop {
    param (
        # The URL of the drop service.
        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [uri]
        $DropServiceURL,

        # The access token for authenticating with the drop service.
        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [securestring]
        $AccessToken,

        # The directory to add to the drop.
        [Parameter(Mandatory)]
        [System.IO.DirectoryInfo]
        $Directory,

        # The name of the drop to finalize.
        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [string]
        $DropName,

        # Lower case the file paths for compatibility across different operating systems.
        [Parameter()]
        [switch]
        $LowerCasePaths,

        # Timeout of this operation.
        [Parameter()]
        [ValidateNotNull()]
        [timespan]
        $Timeout = '0:0:5:0', # 5 minutes

        # Minimum trace detail 'info', 'warn', 'error', 'verbose'.
        [Parameter()]
        [ValidateSet('Info', 'Warn', 'Error', 'Verbose')]
        [string]
        $TraceLevel = 'Verbose',

        # Trace destination file path or 'console' if null.
        [Parameter()]
        [System.IO.FileInfo]
        $TraceTo = $null
    )

    $arguments = "--name '$DropName' --directory '$Directory'"
    if ($LowerCasePaths) {
        $arguments += ' --LowercasePaths'
    }
    Invoke-DropExe -DropServiceURL $DropServiceURL -AccessToken $AccessToken -Command Publish -Arguments $arguments -Timeout $Timeout -TraceLevel $TraceLevel -TraceTo $TraceTo
}

function Complete-ArtifactLogsDrop {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory)]
        [uri]
        $LogsDropServiceURL,

        [Parameter(Mandatory)]
        [string]
        $LogsDropName,

        [Parameter(Mandatory)]
        [securestring]
        $AccessToken
    )

    # DTL only captures the last few thousand characters from stdout in its artifact logs. Let's not pollute them with logging from the logic that publishes logs to a drop.
    $VerbosePreference = 'SilentlyContinue'
    $DebugPreference = 'SilentlyContinue'
    $InformationPreference = 'SilentlyContinue'
    $WarningPreference = 'Continue'
    $ErrorActionPreference = 'Stop'

    $LogsDropName = [System.Environment]::ExpandEnvironmentVariables($LogsDropName)

    $dropExeLogPath = Join-Path $env:TEMP "drop.exe.$(Get-Date -Format FileDateTimeUniversal).log"
    try {
        Complete-AzureArtifactsDrop -DropServiceURL $LogsDropServiceURL -DropName $LogsDropName -AccessToken $AccessToken -TraceTo $dropExeLogPath
    }
    catch {
        Write-Warning "An exeception occurred while attempting to finalize drop '$LogsDropName'. For more information, see the logs at '$dropExeLogPath'. Exception: $($_.Exception.ToString())"
    }
}

function Complete-AzureArtifactsDrop {
    param (
        # The URL of the drop service.
        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [uri]
        $DropServiceURL,

        # The access token for authenticating with the drop service.
        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [securestring]
        $AccessToken,

        # The name of the drop to finalize.
        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [string]
        $DropName,

        # Timeout of this operation.
        [Parameter()]
        [ValidateNotNull()]
        [timespan]
        $Timeout = '0:0:5:0', # 5 minutes

        # Minimum trace detail 'info', 'warn', 'error', 'verbose'.
        [Parameter()]
        [ValidateSet('Info', 'Warn', 'Error', 'Verbose')]
        [string]
        $TraceLevel = 'Verbose',

        # Trace destination file path or 'console' if null.
        [Parameter()]
        [System.IO.FileInfo]
        $TraceTo = $null
    )

    $arguments = "--name '$DropName'"
    Invoke-DropExe -DropServiceURL $DropServiceURL -AccessToken $AccessToken -Command Finalize -Arguments $arguments -Timeout $Timeout -TraceLevel $TraceLevel -TraceTo $TraceTo
}

function ConvertTo-UnsecureString {
    param (
        [Parameter(Mandatory, Position = 0)]
        [securestring]
        $SecureString
    )

    try {
        $BSTR = [System.Runtime.InteropServices.Marshal]::SecureStringToBSTR($SecureString)
        return [System.Runtime.InteropServices.Marshal]::PtrToStringAuto($BSTR)
    }
    finally {
        if ($null -ne $BSTR) {
            [Runtime.InteropServices.Marshal]::ZeroFreeBSTR($BSTR)
        }
    }
}

function Format-AzureArtifactsLogsDropBrowserURL {
    param (
        # Azure DevOps organization URL
        [Parameter(Mandatory)]
        [uri]
        $LogsDropServiceURL,

        # Drop name.
        [Parameter(Mandatory)]
        [string]
        $LogsDropName
    )

    $OrganizationURL = $LogsDropServiceURL -replace 'https:\/\/artifacts\.',  'https://'
    $LogsDropName = [System.Environment]::ExpandEnvironmentVariables($LogsDropName)

    $azureArtifactsDropBrowserURL = "$OrganizationURL/_apps/hub/ms-vscs-artifact.build-tasks.drop-hub-group-explorer-hub?name=$LogsDropName"
    return $azureArtifactsDropBrowserURL
}

# Get access token using an Azure Managed Identity logged in to az accounts.
function Get-AccessTokenUsingManagedIdentity {
    [CmdletBinding()]
    [OutputType([securestring])]
    param (
        # The ClientID of an Azure Managed Identity
        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [string]
        $ClientID
    )

    try {

        Invoke-CommandWithRetry {
            # This is the Azure DevOps resource ID
            $endpointURL = "http://169.254.169.254/metadata/identity/oauth2/token?api-version=2018-02-01&resource=499b84ac-1321-427f-aa17-267ca6975798&client_id=$ClientID"
            $response = Invoke-WebRequest -Uri $endpointURL -Headers @{ Metadata = "true" } -UseBasicParsing
            $content = $response.Content | ConvertFrom-Json
            $accessToken = ConvertTo-SecureString -String $content.access_token -AsPlainText -Force
            return $accessToken
        }
    }
    catch {
        throw "Failed to get access token using managed identity. Exception: $($_.Exception.ToString())"
    }
}

# Computes the path to the latest version of drop.exe and downloads it if not present on the local machine.
function Get-DropExePath {
    param (
        # The URL of the drop service.
        [Parameter(Mandatory)]
        [uri]
        $DropServiceURL
    )
    # Look up the latest version of the drop.exe client
    $localdir = "$env:SystemDrive\DevTestLabs\Drop.App"
    Invoke-CommandWithRetry {
        $response = Invoke-WebRequest -Method Head -Uri "$DropServiceURL/_apis/drop/client/" -UseDefaultCredentials -UseBasicParsing
        $version = $response.Headers["drop-client-version"]
        $localdir = Join-Path $localdir $version
    }
    $dropExePath = Join-Path $localdir 'lib\net45\drop.exe'
    Write-Verbose "Computed drop.exe path as '$dropExePath'."
    if (-not (Test-Path $dropExePath))
    {
        Write-Verbose "The drop.exe client was not found at '$dropExePath'. Attempting to install..."
        $zip = Join-Path $env:TEMP "$(New-Guid).zip"
        try {
            Write-Verbose "Downloading '$zip'..."
            $oldProgressPreference = $ProgressPreference
            $ProgressPreference = "SilentlyContinue"
            Invoke-CommandWithRetry {
                Invoke-WebRequest -Uri "$DropServiceURL/_apis/drop/client/exe" -UseDefaultCredentials -OutFile $zip
            }
            $ProgressPreference = $oldProgressPreference
            Write-Information "Successfully downloaded '$zip'."

            if (Test-Path $localdir) {
                Remove-Item -Path $localdir -Recurse -Force
            }
            New-Item -Path $localdir -ItemType Directory | Out-Null
            Expand-Archive -Path $zip -DestinationPath $localdir
        }
        finally {
            if (Test-Path $zip) {
                try {
                    Remove-Item -Path $zip -Force
                }
                catch {
                    Write-Warning "Unable to clean up temporary file '$zip': $_"
                }
            }
        }
        Write-Information "Successfully installed drop.exe client to '$dropExePath'."
    }

    return $dropExePath
}

function Initialize-Artifact {
    $env:DevTestLabsArtifactsPath = "$env:SystemDrive\DevTestLabs\Artifacts"
}

function Install-AzureArtifactsDrop {
    param (
        # The URL of the drop service.
        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [uri]
        $DropServiceURL,

        # The access token for authenticating with the drop service.
        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [securestring]
        $AccessToken,

        # The name of the drop to finalize.
        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [string]
        $DropName,

        # Directory to store the downloaded drop.
        [Parameter(Mandatory)]
        [System.IO.DirectoryInfo]
        $DestinationDirectory,

        # Timeout of this operation.
        [Parameter()]
        [ValidateNotNull()]
        [timespan]
        $Timeout = '0:0:5:0', # 5 minutes

        # Minimum trace detail 'info', 'warn', 'error', 'verbose'.
        [Parameter()]
        [ValidateSet('Info', 'Warn', 'Error', 'Verbose')]
        [string]
        $TraceLevel = 'Verbose',

        # Trace destination file path or 'console' if null.
        [Parameter()]
        [System.IO.FileInfo]
        $TraceTo = $null
    )

    $arguments = "--name '$DropName' --dest '$DestinationDirectory'"
    Invoke-DropExe -DropServiceURL $DropServiceURL -AccessToken $AccessToken -Command Get -Arguments $arguments -Timeout $Timeout -TraceLevel $TraceLevel -TraceTo $TraceTo
}

function Invoke-CommandWithRetry {
    [CmdletBinding()]
    param (
        # Command(s) to run.
        [Parameter(Mandatory)]
        [scriptblock]
        $ScriptBlock,

        # Number of attempts.
        [Parameter()]
        [int]
        $Attempts = 3,

        # Base delay between retries.
        [Parameter()]
        [timespan]
        $DelayInterval = '0:0:0:5', # 5 seconds

        # Whether or not to employ exponential backoff. Use this calculator to model the retries with your inputs: http://backoffcalculator.com/
        [Parameter()]
        [switch]
        $ExponentialBackoff
    )

    begin {
        $attempt = 1
    }

    process {
        do {
            try {
                Invoke-Command -ScriptBlock $ScriptBlock -NoNewScope
                return
            }
            catch {
                if ($attempt -ge $Attempts) {
                    throw $_
                }
                else {
                    $delay = $DelayInterval
                    if ($ExponentialBackoff) {
                        $delay = [timespan]::FromMilliseconds(([Math]::Pow(2, $attempt) - 1) * $DelayInterval.TotalMilliseconds)
                    }
                    Write-Verbose "Attempt #$attempt failed. Retrying in $($delay.TotalSeconds) second(s)..."
                    $attempt++
                    Start-Sleep -Milliseconds $delay.TotalMilliseconds
                }
            }
        } while ($true)
    }
}

function Invoke-DropExe {
    param (
        # The URL of the drop service.
        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [uri]
        $DropServiceURL,

        # The access token for authenticating with the drop service.
        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [securestring]
        $AccessToken,

        # The drop.exe command to execute.
        [Parameter(Mandatory)]
        [ValidateSet('Create', 'Delete', 'Dir', 'Domain', 'Finalize', 'Get', 'List', 'Publish', 'Update')]
        [string]
        $Command,

        # The arguments to pass to drop.exe.
        [Parameter()]
        [string]
        $Arguments = '',

        # Timeout of this operation.
        [Parameter()]
        [ValidateNotNull()]
        [timespan]
        $Timeout = '0:0:5:0', # 5 minutes

        # Minimum trace detail 'info', 'warn', 'error', 'verbose'.
        [Parameter()]
        [ValidateSet('Info', 'Warn', 'Error', 'Verbose')]
        [string]
        $TraceLevel = 'Verbose',

        # Trace destination file path or 'console' if null.
        [Parameter()]
        [System.IO.FileInfo]
        $TraceTo = $null
    )

    if ($DropServiceURL.Host -eq 'dev.azure.com') {
        $DropServiceURL = [uri]"$($DropServiceURL.Scheme)://artifacts.$($DropServiceURL.Host)$($DropServiceURL.PathAndQuery)"
    }
    elseif ($DropServiceURL.Host -like '*.visualstudio.com') {
        $parts = $DropServiceURL.Host -split '\.'
        if ($parts.Length -eq 3) {
            $DropServiceURL = [uri]"$($DropServiceURL.Scheme)://$($parts[0]).artifacts.$($parts[1]).$($parts[2])$($DropServiceURL.PathAndQuery)"
        }
    }

    $patAuthEnvVarName = (New-Guid).ToString()
    New-Item "env:$patAuthEnvVarName" -Value (ConvertTo-UnsecureString -SecureString $AccessToken) | Out-Null

    $dropExePath = Get-DropExePath -DropServiceURL $DropServiceURL
    Invoke-Expression "& '$dropExePath' $Command --dropservice '$DropServiceURL' --patAuthEnvVar '$patAuthEnvVarName' --timeout '$($Timeout.TotalMinutes)' --tracelevel '$TraceLevel' --traceto '$(if ($TraceTo) { $TraceTo } else { 'console' })' $Arguments"

    switch ($LASTEXITCODE) {
        0 {
            Write-Information "The call to drop.exe succeeded."
        }
        default {
            throw "The call to drop.exe failed with exit code $($LASTEXITCODE)."
        }
    }
}

function New-AzureArtifactsDrop {
    param (
        # The URL of the drop service.
        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [uri]
        $DropServiceURL,

        # The access token for authenticating with the drop service.
        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [securestring]
        $AccessToken,

        # The name of the drop to create.
        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [string]
        $DropName,

        # An expiration date for the drop.
        [Parameter()]
        [datetime]
        $Expiration = ([datetime]::MaxValue),

        # Timeout of this operation.
        [Parameter()]
        [ValidateNotNull()]
        [timespan]
        $Timeout = '0:0:5:0', # 5 minutes

        # Minimum trace detail 'info', 'warn', 'error', 'verbose'.
        [Parameter()]
        [ValidateSet('Info', 'Warn', 'Error', 'Verbose')]
        [string]
        $TraceLevel = 'Verbose',

        # Trace destination file path or 'console' if null.
        [Parameter()]
        [System.IO.FileInfo]
        $TraceTo = $null
    )
    
    $arguments = "--name '$DropName'"

    if ($Expiration -ne [datetime]::MaxValue) {
        $arguments += " --expirationDate '$Expiration'"
    }

    Invoke-DropExe -DropServiceURL $DropServiceURL -AccessToken $AccessToken -Command Create -Arguments $arguments -Timeout $Timeout -TraceLevel $TraceLevel -TraceTo $TraceTo
}

function New-FilesSnapshot {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory)]
        [string]
        $IncludeGlobPatterns,

        [string]
        $ExcludeGlobPatterns,

        [Parameter(Mandatory)]
        [System.IO.DirectoryInfo]
        $SearchDirectory,

        # Must be absolute path
        [Parameter(Mandatory)]
        [System.IO.DirectoryInfo]
        $SnapshotDestinationDirectory,

        [Parameter(Mandatory)]
        [string]
        $SnapshotName
    )

    # DTL only captures the last few thousand characters from stdout in its artifact logs. Let's not pollute them with logging from the logic that publishes logs to a drop.
    $VerbosePreference = 'SilentlyContinue'
    $DebugPreference = 'SilentlyContinue'
    $InformationPreference = 'SilentlyContinue'
    $WarningPreference = 'Continue'
    $ErrorActionPreference = 'Stop'

    try {
        if ($SnapshotDestinationDirectory.Root.Name -ne $SearchDirectory.Root.Name) {
            Throw "Snapshot destination drive '$($SnapshotDestinationDirectory.Root.Name)' is not equal to search drive '$($SearchDirectory.Root.Name)'  The snapshot destination must be on the same drive as the directory being searched"
        }

        $snapshotDirectory = New-Item -Type Directory -Path (Join-Path $SnapshotDestinationDirectory $SnapshotName) -Force

        if ($IncludeGlobPatterns) {
            $includeGlobArray = $IncludeGlobPatterns.split(';')
        }
        else {
            throw "Must supply IncludeGlobPatterns"
        }

        if ($ExcludeGlobPatterns) {
            $excludeGlobArray = $ExcludeGlobPatterns.split(';')
        }

        $filePathsToCopy = Search-File -IncludeGlobPatterns $includeGlobArray -ExcludeGlobPatterns $excludeGlobArray -SearchDirectory $SearchDirectory

        foreach ($path in $filePathsToCopy) {
            try {
                try {
                    $relativePath = Split-Path $path.FullName -NoQualifier
                    $destinationPath = New-Item -Path (Join-Path $snapshotDirectory $relativePath) -Force
                    Copy-Item -Destination $destinationPath -Path $path.FullName -Force
                }
                catch [System.ComponentModel.Win32Exception] {
                    Write-Warning "An exception occured while copying $(Join-Path $SearchDirectory $path) to $destinationPath, attempting to hash the path to make it shorter. Exception: $($_.Exception.ToString())"
                    $pathName = Split-Path -Path $path
                    $pathHash = '{0:x}' -f $pathName.GetHashCode()
                    $fileName = "$pathHash-" + (Split-Path -Path $path -Leaf)
                    $overflowDirectory = Join-Path $snapshotDirectory "MaxFilePathReached"
                    $destinationPath = New-Item -Path (Join-Path $overflowDirectory $fileName) -Force
                    Copy-Item -Destination $destinationPath -Path (Join-Path $SearchDirectory $path) -Force
                }
            }
            catch {
                Write-Warning "An exception occured while copying $(Join-Path $SearchDirectory $path) to $destinationPath. Exception: $($_.Exception.ToString())"
            }
        }
    }
    catch {
        Write-Warning "An exeception occurred while attempting to snapshot (Include:'$IncludeGlobPatterns', Exclude:'$ExcludeGlobPatterns') into '$SnapshotDestinationDirectory' with name '$SnapshotName'. Exception: $($_.Exception.ToString())"
    }
}

function Publish-ArtifactLogs {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory)]
        [uri]
        $LogsDropServiceURL,

        [Parameter(Mandatory)]
        [string]
        $LogsDropName,

        [Parameter(Mandatory)]
        [System.IO.DirectoryInfo]
        $LogsDirectory,

        [Parameter(Mandatory)]
        [securestring]
        $AccessToken
    )

    # DTL only captures the last few thousand characters from stdout in its artifact logs. Let's not pollute them with logging from the logic that publishes logs to a drop.
    $VerbosePreference = 'SilentlyContinue'
    $DebugPreference = 'SilentlyContinue'
    $InformationPreference = 'SilentlyContinue'
    $WarningPreference = 'Continue'
    $ErrorActionPreference = 'Stop'

    $LogsDropName = [System.Environment]::ExpandEnvironmentVariables($LogsDropName)

    $dropExeLogPath = Join-Path $env:TEMP "drop.exe.$(Get-Date -Format FileDateTimeUniversal).log"
    try {
        Add-DirectoryToAzureArtifactsDrop -DropServiceURL $LogsDropServiceURL -DropName $LogsDropName -Directory $LogsDirectory -AccessToken $AccessToken -TraceTo $dropExeLogPath -ErrorAction 'Continue'
    }
    catch {
        try {
            # Publish for the first script will fail because drop does not exist yet, so create it
            $expiration = (Get-Date).AddMonths(1)
            New-AzureArtifactsDrop -DropServiceURL $LogsDropServiceURL -DropName $LogsDropName -Expiration $expiration -AccessToken $AccessToken -TraceTo $dropExeLogPath

            # Try again, now that the drop is created
            Add-DirectoryToAzureArtifactsDrop -DropServiceURL $LogsDropServiceURL -DropName $LogsDropName -Directory $LogsDirectory -AccessToken $AccessToken -TraceTo $dropExeLogPath -ErrorAction 'Continue'
        }
        catch {
            Write-Warning "An exeception occurred while attempting to upload directory '$LogsDirectory' to drop '$LogsDropName'. For more information, see the logs at '$dropExeLogPath'. Exception: $($_.Exception.ToString())"
        }
    }
}

function Search-File {
    param (
        # The directory to search.
        [Parameter(Mandatory)]
        [System.IO.DirectoryInfo]
        $SearchDirectory,

        # Glob patterns to include.
        [Parameter(Mandatory)]
        [string[]]
        $IncludeGlobPatterns,

        # Glob patterns to exclude.
        [Parameter()]
        [string[]]
        $ExcludeGlobPatterns = $null
    )

    $includeFileSystemPaths = @()
    foreach ($glob in $IncludeGlobPatterns) {
        $includeFileSystemPaths += Search-FileSystemRecurse -Directory $SearchDirectory -GlobParts (Split-GlobStar -Glob $glob)
    }
    $includeFileSystemPaths = $includeFileSystemPaths | Select-Object -Unique

    $excludeFileSystemPaths = @()
    foreach ($glob in $ExcludeGlobPatterns) {
        $excludeFileSystemPaths += Search-FileSystemRecurse -Directory $SearchDirectory -GlobParts (Split-GlobStar -Glob $glob)
    }
    $excludeFileSystemPaths = $excludeFileSystemPaths | Select-Object -Unique

    # Get the relative complement of excluded files in included files.
    $fileSystemPaths = $includeFileSystemPaths | Where-Object { $excludeFileSystemPaths -NotContains $_ }

    $results = @()
    foreach ($fileSystemPath in $fileSystemPaths) {
        # We only want files, no directories.
        if (Test-Path $fileSystemPath -PathType Leaf) {
            $results += [System.IO.FileInfo]$fileSystemPath
        }
    }
    return $results
}

# Returns the resolved paths of file system entries under the given directory that match the given glob parts.
# Results may include directories and files and contain duplicates.
function Search-FileSystemRecurse {
    param (
        # The path
        [Parameter(Mandatory)]
        [System.IO.DirectoryInfo]
        $Directory,

        # The glob
        [Parameter(Mandatory)]
        [string[]]
        $GlobParts
    )

    $glob, $globRemainder = $GlobParts

    $result = @()
    if ($glob -eq '**') {
        foreach ($subdirectory in $Directory.EnumerateDirectories()) {
            $result += Search-FileSystemRecurse -Directory $subdirectory -GlobParts $GlobParts
        }
        $result += Search-FileSystemRecurse -Directory $Directory -GlobParts $(if ($globRemainder) { $globRemainder } else { '*' })
    }
    else {
        $matchingPaths = @(Resolve-Path -Path (Join-Path $Directory.FullName $glob) -ErrorAction SilentlyContinue | Select-Object -ExpandProperty Path)
        if ($globRemainder) {
            foreach ($path in $matchingPaths) {
                Search-FileSystemRecurse -Directory $path -GlobParts $globRemainder
            }
        }
        else {
            $result += $matchingPaths
        }
    }

    return $result
}

# What is a globstar? According to the GNU organization, it is the ** pattern used to "match all files and zero or more directories and subdirectories".
# https://www.gnu.org/software/bash/manual/html_node/Pattern-Matching.html
function Split-GlobStar {
    param (
        # Parameter help description
        [Parameter(Mandatory)]
        [string]
        $Glob
    )

    $normalizedGlob = $Glob.Replace('/', '\')
    # A glob ending in '\' should be treated as a globstar, according to https://learn.microsoft.com/en-us/dotnet/core/extensions/file-globbing#pattern-formats
    if ($normalizedGlob.EndsWith('\')) {
        $normalizedGlob += '**'
    }
    $parts = $normalizedGlob.Split('\', [StringSplitOptions]::RemoveEmptyEntries)
    $result = @()

    $currentPart = $null
    foreach ($part in $parts) {
        if ($part -eq '**') {
            if ($currentPart) {
                $result += $currentPart
                $currentPart = $null
            }
            # Following logic removes multiple consecutive globstar (**) parts from the string because they are functionally equivalent and computationally intensive.
            # For example, '**/**' is functionally equivalent to '**'.
            if ((Select-Object $result -Last 1) -ne '**') {
                $result += $part
            }
        }
        else {
            if ($currentPart) {
                $currentPart = Join-Path $currentPart $part
            }
            else {
                $currentPart = $part
            }
        }
    }
    if ($currentPart) {
        $result += $currentPart
    }

    return $result
}

function Start-ArtifactLogging {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory)]
        [System.IO.FileInfo]
        $LogFile
    )
    # Disable all confirmation dialogs because they can block automation
    $global:ConfirmPreference = 'None'

    $global:DebugPreference = 'Continue'
    $global:VerbosePreference = 'Continue'
    $global:InformationPreference = 'SilentlyContinue' # Due a bug in Windows PowerShell, Write-Information will only appear in transcripts if InformationPreference is set to 'SilentlyContinue'
    $global:WarningPreference = 'Continue'
    $global:ErrorActionPreference = 'Stop'

    # Set up transcript
    if (-not (Test-Path -Path $LogFile.Directory -PathType Container)) {
        New-Item -Path $LogFile.Directory -ItemType Directory -Force | Out-Null
    }
    Start-Transcript -Path $LogFile
}

function Stop-ArtifactLogging {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory)]
        [System.IO.FileInfo]
        $LogFile
    )

    Stop-Transcript
    
    # Adjust log levels to not pollute StOut with messages unrelated to the actual artifact execution
    $global:DebugPreference = 'SilentlyContinue'
    $global:VerbosePreference = 'SilentlyContinue'
    $global:InformationPreference = 'SilentlyContinue'
    $global:WarningPreference = 'Continue'
    $global:ErrorActionPreference = 'Continue'

    # Need to remove the invocation header from the log file because it may contain secrets.
    $tempLogFile = New-TemporaryFile
    Move-Item -Path $LogFile -Destination $tempLogFile -Force
    Get-Content -Path $tempLogFile | Where-Object { $_ -NotMatch "^Host Application:" } | Set-Content -Path $logFile
    Remove-Item -Path $tempLogFile -Force
}

function Test-RebootPending {
    return (Test-Path (Join-Path $env:DevTestLabsArtifactsPath 'RebootPending.sem'))
}

function Write-ToArtifactOrchestrator {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory)]
        [string]
        $message,

        [Parameter(Mandatory)]
        [ValidateSet('Debug', 'Information', 'Warning', 'Error')]
        [string]
        $logLevel
    )

    Write-Host "##DevTestLabs(LogLevel=$logLevel;Message=$message)"
}

# Log must appear in the last 50 lines of StOut to be read by the artifact orchestrator
function Write-ErrorToArtifactOrchestrator {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory)]
        [string]
        $message
    )

    Write-ToArtifactOrchestrator -Message $message -LogLevel "Error"
}

# Log must appear in the last 50 lines of StOut to be read by the artifact orchestrator
function Write-DebugToArtifactOrchestrator {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory)]
        [string]
        $message
    )

    Write-ToArtifactOrchestrator -Message $message -LogLevel "Debug"
}

# Log must appear in the last 50 lines of StOut to be read by the artifact orchestrator
function Write-InformationToArtifactOrchestrator {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory)]
        [string]
        $message
    )

    Write-ToArtifactOrchestrator -Message $message -LogLevel "Information"
}

# Log must appear in the last 50 lines of StOut to be read by the artifact orchestrator
function Write-WarningToArtifactOrchestrator {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory)]
        [string]
        $message
    )

    Write-ToArtifactOrchestrator -Message $message -LogLevel "Warning"
}

Export-ModuleMember -Function Add-DirectoryToAzureArtifactsDrop
Export-ModuleMember -Function Complete-ArtifactLogsDrop
Export-ModuleMember -Function Complete-AzureArtifactsDrop
Export-ModuleMember -Function Format-AzureArtifactsLogsDropBrowserURL
Export-ModuleMember -Function Get-AccessTokenUsingManagedIdentity
Export-ModuleMember -Function Initialize-Artifact
Export-ModuleMember -Function Install-AzureArtifactsDrop
Export-ModuleMember -Function New-AzureArtifactsDrop
Export-ModuleMember -Function New-FilesSnapshot
Export-ModuleMember -Function Publish-ArtifactLogs
Export-ModuleMember -Function Search-File
Export-ModuleMember -Function Start-ArtifactLogging
Export-ModuleMember -Function Stop-ArtifactLogging
Export-ModuleMember -Function Test-RebootPending
Export-ModuleMember -Function Write-ErrorToArtifactOrchestrator
Export-ModuleMember -Function Write-DebugToArtifactOrchestrator
Export-ModuleMember -Function Write-InformationToArtifactOrchestrator
Export-ModuleMember -Function Write-WarningToArtifactOrchestrator