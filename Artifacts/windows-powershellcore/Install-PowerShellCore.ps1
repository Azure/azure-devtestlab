[CmdletBinding()]
param
(
    [String]
    $PackageUrl,

    [switch]
    $InstallCRuntime
)

###################################################################################################
#
# PowerShell configurations
#

# NOTE: Because the $ErrorActionPreference is "Stop", this script will stop on first failure.
#       This is necessary to ensure we capture errors inside the try-catch-finally block.
$ErrorActionPreference = 'Stop'

# Suppress progress bar output.
$ProgressPreference = 'SilentlyContinue'

# Ensure we force use of TLS 1.2 for all downloads.
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12

###################################################################################################
#
# Handle all errors in this script.
#

trap
{
    # NOTE: This trap will handle all errors. There should be no need to use a catch below in this
    #       script, unless you want to ignore a specific error.
    $message = $Error[0].Exception.Message
    if ($message)
    {
        Write-Host -Object "`nERROR: $message" -ForegroundColor Red
    }

    Write-Host "`nThe artifact failed to apply.`n"

    # IMPORTANT NOTE: Throwing a terminating error (using $ErrorActionPreference = "Stop") still
    # returns exit code zero from the PowerShell script when using -File. The workaround is to
    # NOT use -File when calling this script and leverage the try-catch-finally block and return
    # a non-zero exit code from the catch block.
    exit -1
}

###################################################################################################
#
# Functions used in this script.
#

function Get-PowerShellCore
{
    [CmdletBinding()]
    param
    (
        [String]
        $PackageUrl
    )

    $coreMsi = "${env:Temp}\PowerShellCore.msi"

    $null = Invoke-WebRequest -Uri $PackageUrl -OutFile $coreMsi

    if (-not (Test-Path -Path $coreMsi))
    {
        throw "Failed to download $PackageUrl."
    }

    return $coreMsi
}

function Install-CRuntime
{
   [CmdletBinding()]
    param()

    $osVersion = (Get-WmiObject -Class Win32_OperatingSystem).Name.Split('|')[0]
    if ($osVersion -like "Microsoft Windows Server 2012 R2*")
    {
        $ucRuntimeUri = 'https://download.microsoft.com/download/3/1/1/311C06C1-F162-405C-B538-D9DC3A4007D1/WindowsUCRT.zip'
        $ucArchive = "${env:Temp}\WindowsUCRT.zip"
        $ucFiles = "${env:Temp}\ucFiles"
        $msuPath = "${env:Temp}\ucFiles\Windows8.1-KB3118401-x64.msu"

        try
        {
            Write-Host 'Acquiring C runtime installer.'
            Invoke-WebRequest -Uri $ucRuntimeUri -OutFile $ucArchive | Out-Null

            Write-Host 'Extracting downloaded archive to $ucFiles.'
            Add-Type -assembly 'System.IO.Compression.FileSystem'
            [IO.Compression.ZipFile]::ExtractToDirectory($ucArchive, $ucFiles)

            Write-Host "Installing Universal C runtime from $msuPath."
            Invoke-Process -FilePath wusa.exe -ArgumentList "/install $msuPath /quiet"
        }
        finally
        {
            if ($msuPath)
            {
                Remove-Item -Path $msuPath -ErrorAction SilentlyContinue -Force
            }
            if ($ucFiles)
            {
                Remove-Item -Path $ucFiles -ErrorAction SilentlyContinue -Recurse -Force
            }
            if ($ucArchive)
            {
                Remove-Item -Path $ucArchive -ErrorAction SilentlyContinue -Force
            }
        }
    }
}

function Install-PowerShellCore
{
    [CmdletBinding()]
    param
    (
        [String]
        $Msi
    )

    Invoke-Process -FilePath msiexec.exe -ArgumentList "/i $Msi /quiet /qn /lvx* PowerShellCore.log"
}

function Invoke-Process
{
    param
    (
        [String]
        $FilePath = $(throw "The FileName must be provided."),
        [String]
        $ArgumentList = ''
    )

    # Prepare specifics for starting the process that will install the component.
    $startInfo = New-Object System.Diagnostics.ProcessStartInfo
    $startInfo.Arguments = $ArgumentList
    $startInfo.CreateNoWindow = $true
    $startInfo.ErrorDialog = $false
    $startInfo.FileName = $FilePath
    $startInfo.RedirectStandardError = $true
    $startInfo.RedirectStandardInput = $true
    $startInfo.RedirectStandardOutput = $true
    $startInfo.UseShellExecute = $false
    $startInfo.WindowStyle = [System.Diagnostics.ProcessWindowStyle]::Hidden
    $startInfo.WorkingDirectory = $wd

    # Initialize a new process.
    $process = New-Object System.Diagnostics.Process
    try
    {
        # Configure the process so we can capture all its output.
        $process.EnableRaisingEvents = $true
        # Hook into the standard output and error stream events
        $errEvent = Register-ObjectEvent -SourceIdentifier OnErrorDataReceived $process "ErrorDataReceived" `
            `
            {
                param
                (
                    [System.Object] $sender,
                    [System.Diagnostics.DataReceivedEventArgs] $e
                )
                foreach ($s in $e.Data) { if ($s) { Write-Host "$s" -ForegroundColor Red -NoNewline } }
            }
        $outEvent = Register-ObjectEvent -SourceIdentifier OnOutputDataReceived $process "OutputDataReceived" `
            `
            {
                param
                (
                    [System.Object] $sender,
                    [System.Diagnostics.DataReceivedEventArgs] $e
                )
                foreach ($s in $e.Data) { if ($s) { Write-Host "$s" -NoNewline } }
            }
        $process.StartInfo = $startInfo;
        Write-Host "Executing $FilePath $ArgumentList"

        # Attempt to start the process.
        if ($process.Start())
        {
            # Read from all redirected streams before waiting to prevent deadlock.
            $process.BeginErrorReadLine()
            $process.BeginOutputReadLine()
            # Wait for the application to exit for no more than 5 minutes.
            $process.WaitForExit(300000) | Out-Null
        }

        # Determine if process failed to execute.
        if ($process.ExitCode -eq 3010)
        {
            Write-Host 'The recent changes indicate a reboot is necessary. Please reboot at your earliest convenience.'
        }
        elseif ($process.ExitCode -eq 2359302)
        {
            # Ignore it as valid, as it means that a patch has already been applied.
        }
        elseif ($process.ExitCode -ne 0)
        {
            # Throwing an exception at this point will stop any subsequent
            # attempts for deployment.
            throw New-Object System.Exception($startInfo.FileName + ' exited with code: ' + $process.ExitCode)
        }
    }
    finally
    {
        # Free all resources associated to the process.
        $process.Close();
        
        # Remove any previous event handlers.
        Unregister-Event OnErrorDataReceived -Force | Out-Null
        Unregister-Event OnOutputDataReceived -Force | Out-Null
    }
}

function Test-PackageUrl
{
    [CmdletBinding()]
    param
    (
        [String]
        $PackageUrl
    )

    if (-not (Split-Path -Path $PackageUrl -Leaf).EndsWith('.msi'))
    {
        throw "$PackageUrl is not the path to a PowerShell Core MSI."
    }
}

###################################################################################################
#
# Main execution block.
#

[string] $coreMsi

try
{
    pushd $PSScriptRoot

    Write-Host 'Validating input parameters.'
    Test-PackageUrl -PackageUrl $PackageUrl

    Write-Host "Downloading $PackageUrl."
    $coreMsi = Get-PowerShellCore -PackageUrl $PackageUrl

    if ($InstallCRuntime)
    {
        Install-CRuntime
    }

    Write-Host 'Installing PowerShell Core.'
    Install-PowerShellCore -Msi $coreMsi

    Write-Host "`nThe artifact was applied successfully.`n"
}
finally
{
    if ($coreMsi)
    {
        Remove-Item -Path $coreMsi -ErrorAction SilentlyContinue -Force
    }
    Pop-Location
}
