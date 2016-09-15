Param(
    [Parameter(
        HelpMessage="Where to download the gVim installer to on the local machine. Defaults to %TEMP%\gvim.exe"
    )]
    [String]
    $VimInstallerPath = (Join-Path -Path $Env:TEMP -ChildPath "gvim.exe"),
    [Parameter(
        HelpMessage="Where to download the gVim installer from"
    )]
    [String]
    $VimInstallerUri = "https://sourceforge.net/projects/cream/files/Vim/7.4.1641/gvim-7-4-1641.exe/download"
)

# Ensure we are able to run in an elevated mode
Set-ExecutionPolicy -ExecutionPolicy Bypass -Scope Process -Force

# Function to write log messages requires a log folder.
New-Item -Path "C:\Temp\Log" -Force -ItemType Directory | Out-Null

Function Write-Log {
    Param(
        # Specifies a path to one or more locations.
        [Parameter(Mandatory=$true,
                   Position=0,
                   ValueFromPipeline=$true,
                   ValueFromPipelineByPropertyName=$true,
                   HelpMessage="Message to write to the log.")]
        [string[]]
        $Message,
        [Parameter(Mandatory=$false)]
        [string]
        $LogFile="C:\Temp\Log\install-gvim.log"
    )

    $("[" + [System.DateTime]::Now + "] " + $Message) | % {
        Out-File -InputObject $_ -FilePath $LogFile -Append
    }
}

Write-Log "Check that the installer doesn't already exist. If so, we will delete it."
# Ensure the path is clear for us to download to our installer path...
if (Test-Path -Path $VimInstallerPath -ErrorAction SilentlyContinue)
{
    Write-Log "We found a prior download for this installer. Deleting it."
    $newItem = Remove-Item -Path $VimInstallerPath -Force -ErrorAction SilentlyContinue
    Write-Log $newItem
}

# Ensure the actual folder we specified to store the installer in exists! (the defualt will, but if we override it later we may have to create it)
Write-Log "Ensure the download-to local folder exists. If not, create it."
if (-not(Test-Path -Path (Split-Path $VimInstallerPath) -ErrorAction SilentlyContinue))
{
    Write-Log "The folder we are downloading to doesn't exist. Creating it."
    $newItem = New-Item -ItemType Directory -Path (Split-Path $VimInstallerPath) -Force
    Write-Log $newItem
}

# Invoke-WebRequest and Start-BitsTransfer don't seem to play nice with the redirection that happens on sourceforge.net, 
# use WebClient instead.
Write-Log "Download the file from '$VimInstallerUri' to '$VimInstallerPath'"
$wc = New-Object System.Net.WebClient
$wc.DownloadFile($VimInstallerUri,$VimInstallerPath)

# Wait for the installer to finish so we don't report success prior to being done.
Write-Log "Running the installer for gvim with the unattended switch /S."
Start-Process -FilePath $VimInstallerPath -ArgumentList @('/S') -Verb "RunAs" -Wait

# Done!
Write-Log "Complete."
