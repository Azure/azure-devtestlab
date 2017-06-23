[CmdletBinding()]
param(
    [string] $VSVersion
)

###################################################################################################

#
# PowerShell configurations
#

# NOTE: Because the $ErrorActionPreference is "Stop", this script will stop on first failure.
#       This is necessary to ensure we capture errors inside the try-catch-finally block.
$ErrorActionPreference = "Stop"

# Ensure we set the working directory to that of the script.
pushd $PSScriptRoot

# Configure strict debugging.
Set-PSDebug -Strict

###################################################################################################

#
# Functions used in this script.
#

function Handle-LastError
{
    [CmdletBinding()]
    param(
    )

    $message = $error[0].Exception.Message
    if ($message)
    {
        Write-Host -Object "ERROR: $message" -ForegroundColor Red
    }
    
    # IMPORTANT NOTE: Throwing a terminating error (using $ErrorActionPreference = "Stop") still
    # returns exit code zero from the PowerShell script when using -File. The workaround is to
    # NOT use -File when calling this script and leverage the try-catch-finally block and return
    # a non-zero exit code from the catch block.
    exit -1
}

function Get-VSVersionNumber
{
    [CmdletBinding()]
    param(
        [string] $VSVersion
    )
    
    switch ($VSVersion)
    {
        'Visual Studio 2015' { return 14 }
        'Visual Studio 2017' { return 15 }
        default { throw "Unsupported Visual Studio version specified: $VSVersion" }
    }
}

function Get-VSSetupInstances
{
    [CmdletBinding()]
    param(
    )

    if (-not (Get-Module -ListAvailable -Name VSSetup))
    {
        Install-Module VSSetup -Scope CurrentUser -Force
    }

    # Get VS installation information.
    return Get-VSSetupInstance
}

function Test-VSVersion
{
    [CmdletBinding()]
    param(
        [string] $VSVersion
    )

    $foundDesiredVSVersion = $false

    $vsVersionNumber = Get-VSVersionNumber -VSVersion $VSVersion
    switch ($vsVersionNumber)
    {
        14
        {
            $foundDesiredVSVersion = Test-Path "Registry::HKEY_LOCAL_MACHINE\SOFTWARE\Microsoft\VisualStudio\$vsVersionNumber.0"
        }
        
        default
        {
            # Get VS installation information.
            $vsInstances = Get-VSSetupInstances

            # See if any major version of installed products match the desired VS version.
            $vsInstances | % {
                Write-Host "Found version '$($_.InstallationVersion)' of Visual Studio installed at $($_.InstallationPath)."
                if ($_.InstallationVersion.Major -eq $vsVersionNumber)
                {
                    $foundDesiredVSVersion = $true
                    break;
                }
            }
        }
    }

    if (-not $foundDesiredVSVersion)
    {
        throw "Unable to find specified version: $VSVersion. It must be installed before preceeding."
    }
}

function Invoke-Process
{
    [CmdletBinding()]
    param (
        [string] $FileName = $(throw 'The FileName must be provided'),
        [string] $Arguments = '',
        [Array] $ValidExitCodes = @()
    )

    Write-Host "Running command '$FileName $Arguments'"

    # Prepare specifics for starting the process that will install the component.
    $startInfo = New-Object System.Diagnostics.ProcessStartInfo -Property @{
        Arguments = $Arguments
        CreateNoWindow = $true
        ErrorDialog = $false
        FileName = $FileName
        RedirectStandardError = $true
        RedirectStandardInput = $true
        RedirectStandardOutput = $true
        UseShellExecute = $false
        Verb = 'runas'
        WindowStyle = [System.Diagnostics.ProcessWindowStyle]::Hidden
        WorkingDirectory = $PSScriptRoot
    }

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
                foreach ($s in $e.Data) { if ($s) { Write-Host $err $s -ForegroundColor Red } }
            }
        $outEvent = Register-ObjectEvent -SourceIdentifier OnOutputDataReceived $process "OutputDataReceived" `
            `
            {
                param
                (
                    [System.Object] $sender,
                    [System.Diagnostics.DataReceivedEventArgs] $e
                )
                foreach ($s in $e.Data) { if ($s -and $s.Trim('. ').Length -gt 0) { Write-Host $s } }
            }
        $process.StartInfo = $startInfo;
        # Attempt to start the process.
        if ($process.Start())
        {
            # Read from all redirected streams before waiting to prevent deadlock.
            $process.BeginErrorReadLine()
            $process.BeginOutputReadLine()
            # Wait for the application to exit for no more than 5 minutes.
            $process.WaitForExit(300000) | Out-Null
        }
        # Ensure we extract an exit code, if not from the process itself.
        $exitCode = $process.ExitCode
        # Determine if process requires a reboot.
        if ($exitCode -eq 3010)
        {
            Write-Host 'The recent changes indicate a reboot is necessary. Please reboot at your earliest convenience.'
        }
        elseif ($ValidExitCodes.Contains($exitCode))
        {
            Write-Host "$FileName exited with expected valid exit code: $exitCode"
            # Override to ensure the overall script doesn't fail.
            $LASTEXITCODE = 0
        }
        # Determine if process failed to execute.
        elseif ($exitCode -gt 0)
        {
            # Throwing an exception at this point will stop any subsequent
            # attempts for deployment.
            throw "$FileName exited with code: $exitCode"
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

function Install-WebPlatformInstaller
{
    [CmdletBinding()]
    param(
    )

    if (Test-Path "Registry::HKEY_LOCAL_MACHINE\SOFTWARE\Microsoft\WebPlatformInstaller")
    {
        Write-Host 'Web Platform Installer already installed'
    }
    else
    {
        # Get MSI to install Web Platform Installer URL.
        if ($ENV:PROCESSOR_ARCHITECTURE -eq 'AMD64')
        {
            $wpiPackage = "http://download.microsoft.com/download/C/F/F/CFF3A0B8-99D4-41A2-AE1A-496C08BEB904/WebPlatformInstaller_amd64_en-US.msi"
        }
        else
        {
            $wpiPackage = "http://download.microsoft.com/download/C/F/F/CFF3A0B8-99D4-41A2-AE1A-496C08BEB904/WebPlatformInstaller_x86_en-US.msi"
        }

        Write-Host "Installing Web Platform Installer"
        Invoke-Process -FileName "$env:windir\system32\msiexec.exe" -Arguments "/quiet /norestart /package $wpiPackage"
    }
}

function Get-WebPlatformInstaller
{
    [CmdletBinding()]
    param(
    )

    $wpiInfo = (ls "Registry::HKEY_LOCAL_MACHINE\SOFTWARE\Microsoft\WebPlatformInstaller")[-1].Name
    return Join-Path (Get-ItemProperty -Path "Registry::$wpiInfo" -Name 'InstallPath').InstallPath 'webpicmd.exe'
}

function Get-ServiceFabricSdkProductId
{
    [CmdletBinding()]
    param(
        [int] $VSVersionNumber
    )

    # Get correct Service Fabric SDK Product ID for version of VS that is installed.
    switch ($VSVersionNumber){
        14 { return 'MicrosoftAzure-ServiceFabric-VS2015' }  #tools and sdk
        default { return 'MicrosoftAzure-ServiceFabric-CoreSDK' } #core sdk only
    }
}

function Install-ServiceFabricSdk
{
    [CmdletBinding()]
    param(
        [int] $VSVersionNumber,
        [string] $LogPath = $(Join-Path $env:Temp 'ServiceFabricSDK.log')
    )

    $wpiExe = Get-WebPlatformInstaller
    $productId = Get-ServiceFabricSdkProductId -VSVersionNumber $VSVersionNumber
    
    Invoke-Process -FileName $wpiExe -Arguments "/Offline /Products:$productId /Path:$($env:Temp)\OfflineCache"
    Invoke-Process -FileName $wpiExe -Arguments "/Install /Products:$productId /AcceptEula /SuppressReboot /SuppressPostFinish /Log:$LogPath /xml:$($env:Temp)\OfflineCache\feeds\latest\webproductlist.xml"
}

function Enable-ServiceFabricTools
{
    [CmdletBinding()]
    param(
        [int] $VSVersionNumber
    )

    $vsBootstrapperExe = Join-Path $env:Temp "vsbootstrap.exe"
    $vsBootstrapperUrl = "https://aka.ms/vs/$VSVersionNumber/release/vs_enterprise.exe"

    Write-Host "Downloading Visual Studio bootstrapper from $vsBootstrapperUrl"
    try 
    {
        (New-Object System.Net.WebClient).DownloadFile($vsBootstrapperUrl, $vsBootstrapperExe)
    }
    catch [System.Management.Automation.MethodInvocationException]
    {
        throw "Unable to find Visual Studio bootstapper at $vsBootstrapperUrl"
    }

    if (-not (Test-Path $vsBootstrapperExe))
    {
        throw "Visual Studio bootstrapper was not successfully downloaded to $vsBootstrapperExe"
    }

    Write-Host 'Getting Visual Studio Installer path'
    $vsInstallerExePath = (Get-ItemProperty -Path "Registry::HKEY_LOCAL_MACHINE\SOFTWARE\WOW6432Node\Microsoft\Windows\CurrentVersion\Uninstall\{6F320B93-EE3C-4826-85E0-ADF79F8D4C61}" -Name 'InstallLocation').InstallLocation.Trim('"')
    $vsInstallExe = Join-Path $vsInstallerExePath  'vs_installer.exe'
    Write-Host "Visual Studio Installer is at $vsInstallExe"

    # Get VS installation information.
    $vsInstances = Get-VSSetupInstances

    # Add Service Fabric component to all Visual Studio instances.
    $vsInstances | % {
        if ($_.InstallationVersion.Major -eq $VSVersionNumber)
        {
            # We must do an update to restore the channel used for modifying the Visual Studio Instance.
            Write-Host 'Updating Visual Studio instance'
            Invoke-Process -FileName $vsBootstrapperExe -Arguments "update --installPath `"$($_.InstallationPath)`" --quiet --wait" -ValidExitCodes 1
         
            # Modify the Visual Studio instance with Service Fabric SDK components.
            Write-Host "Enabling Service Fabric Tools component for installation $($_.InstallationPath)"
            Invoke-Process -FileName $vsInstallExe -Arguments "modify --installPath `"$($_.InstallationPath)`" --add Microsoft.VisualStudio.Workload.Azure --add Microsoft.VisualStudio.Component.Azure.ServiceFabric.Tools --quiet --norestart --wait" -ValidExitCodes 1
        }
    }
}

###################################################################################################

#
# Handle all errors in this script.
#

trap
{
    # NOTE: This trap will handle all errors. There should be no need to use a catch below in this
    #       script, unless you want to ignore a specific error.
    Handle-LastError
}

###################################################################################################

#
# Main execution block.
#

try
{
    # Change the "Locall AppData" path to a location where the process can write, or the relevant
    # VS installer components will fail to complete.
    reg add "hku\.default\software\microsoft\windows\currentversion\explorer\user shell folders" /v "Local AppData" /t REG_EXPAND_SZ /d "$($env:Temp)\AppData\Local" /f

    Write-Host "Validating version specified: $VSVersion"
    Test-VSVersion -VSVersion $VSVersion

    Write-Host "Fetching $VSVersion details"
    $vsVersionNumber = Get-VSVersionNumber -VSVersion $VSVersion

    Write-Host 'Looking for Web Platform Installer'
    Install-WebPlatformInstaller

    Write-Host 'Installing Service Fabric SDK'
    Install-ServiceFabricSdk -VSVersionNumber $vsVersionNumber

    if ($vsVersionNumber -ge 15)
    {
        Write-Host 'Enabling Service Fabric Tools'
        Enable-ServiceFabricTools -VSVersionNumber $vsVersionNumber
    }
}
finally
{
    $exitCode = $LASTEXITCODE
    # Restore system to state prior to execution of this script.
    reg add "hku\.default\software\microsoft\windows\currentversion\explorer\user shell folders" /v "Local AppData" /t REG_EXPAND_SZ /d %%USERPROFILE%%\AppData\Local /f
    popd
    exit $exitCode
}
