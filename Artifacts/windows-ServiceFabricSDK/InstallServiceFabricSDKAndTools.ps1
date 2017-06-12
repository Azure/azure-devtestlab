[CmdletBinding()]
Param(
    [ValidateSet(14, 15)][Parameter(Mandatory=$True)][int] $VSVersion
)
$ErrorActionPreference = "Stop"

#Function will run specified process and wait for it to exit. 
#  Function will also verify process exit code is in validProcessExitCodes (if specified)
function StartAndWaitForProcess{
    Param(
        [string] $filePath,
        [string] $argString,
        [int[]] $validProcessExitCodes
    )

    if($validProcessExitCodes -ne $null){
        Write-Verbose "Running command '$filePath $argString'. Valid exit codes are: $($validProcessExitCodes -join ',')"
    }else{
        Write-Verbose "Running command '$filePath $argString'."
    }
    $processInfo = Start-Process -FilePath $filePath -ArgumentList $argString -Wait -PassThru

    if($validProcessExitCodes -ne $null){
        if ($validProcessExitCodes.Contains($processInfo.ExitCode) -eq $false){
            Write-Error "$filePath failed with exit code  $($processInfo.ExitCode)." 
            return -1
        }
        else
        {
            Write-Verbose "$filePath completed with code $($processInfo.ExitCode)."
        }
    }
}

### Verify Visual Studio is already installed
$foundDesiredVSVersion = $false
if ($VSVersion -eq 14){
    $foundDesiredVSVersion = (Test-Path "Registry::HKEY_LOCAL_MACHINE\SOFTWARE\Microsoft\VisualStudio\$VSVersion.0")
}else{
    #Get VS installation information
    Install-Module VSSetup -Scope CurrentUser -Force
    $vsInstallInfoArray = @(Get-VSSetupInstance)
   
     #See if any major version of installed products match desired VS version  
     foreach ($VSInstallPathInfo in $vsInstallInfoArray){
           Write-Verbose "Found version '$($VSInstallPathInfo.InstallationVersion)' of Visual Studio installed at $($VSInstallPathInfo.InstallationPath)"
        if ((new-Object -TypeName 'System.Version' -ArgumentList $VSInstallPathInfo.InstallationVersion).Major -eq $VSVersion){
            $foundDesiredVSVersion = $true
            break;
        }
   }
}

#Fail package if desired VS version is not found
if ($foundDesiredVSVersion -eq $false){
    Write-Error "Unable to find version $VSVersion installed on the machine.  Visual Studio must be installed before preceeding."
    return -1
}

### Install Web Platform Installer, if not already installed. ###
if ((Test-Path 'Registry::HKEY_LOCAL_MACHINE\SOFTWARE\Microsoft\WebPlatformInstaller') -eq  $false){
   #Get Msi to install WebPI
    If ($ENV:PROCESSOR_ARCHITECTURE -eq "AMD64")
    {
        $WebPIInstall = "http://download.microsoft.com/download/C/F/F/CFF3A0B8-99D4-41A2-AE1A-496C08BEB904/WebPlatformInstaller_amd64_en-US.msi"
    }
    else
    {
        $WebPIInstall = "http://download.microsoft.com/download/C/F/F/CFF3A0B8-99D4-41A2-AE1A-496C08BEB904/WebPlatformInstaller_x86_en-US.msi"
    }

    #Install WebPI
    Write-Verbose "Installing Web Platform Installer."
    StartAndWaitForProcess  "$env:windir\system32\msiexec.exe" "/quiet /norestart /package $WebPIInstall" @(0)
}else{
    Write-Verbose "Web Platform Installer already installed on the machine."
}

### Install Service Fabric SDK###
#Get path to latest WebPI exe
$webInstallerKeyInfo = @(Get-ChildItem -Path 'Registry::HKEY_LOCAL_MACHINE\SOFTWARE\Microsoft\WebPlatformInstaller')
$latestWebInstallerInfo = ($webInstallerKeyInfo[$webInstallerKeyInfo.Count-1]).Name
$WebPICmdExe = Join-Path (Get-ItemProperty -Path "Registry::$latestWebInstallerInfo" -Name 'InstallPath').InstallPath 'WebpiCmd.exe' 

#Get correct Service Fabric SDK product id for version of VS that is installed
switch ($VSVersion){
    14 {$ProductId = 'MicrosoftAzure-ServiceFabric-VS2015'}  #tools and sdk
    default {$ProductId = 'MicrosoftAzure-ServiceFabric-CoreSDK'} #core sdk only
}
Write-Verbose "Product Id for Service Fabric SDK is $ProductId."

#Install SDK
Write-Output "Installing Service Fabric SDK."
StartAndWaitForProcess $WebPICmdExe  "/Install /Products:$ProductId /AcceptEula /SuppressReboot /SuppressPostFinish"  #@(0,3010)

#Verify SDK installed successfuly
#Note: Unable to verify sdk install for VS2015 at this time.
if($VSVersion -ge 15){
    $webpiInstalledProducts = & $WebPICmdExe /List /ListOption:Installed | Out-String
    if(($webpiInstalledProducts -match $ProductId) -eq $false){
        Write-Error "$ProductId was not successfully installed via WebPI."
        return -1
    } else {
        Write-Verbose "$ProductId was successfully installed via WebPI."
    }
}

### For VS2017, must also enable component for Service Fabric tools
if ($VSVersion -ge 15){
    #update the installer
    $vsBootstrapperExe = Join-Path $env:Temp "vsbootstrap.exe"
    $vsBootstrapperUrl = 'https://aka.ms/vs/15/release/vs_enterprise.exe'
    Write-Verbose "Downloading Visual Studio bootstrapper from $vsBootstrapperUrl."
    try 
    {
        (New-Object System.Net.WebClient).DownloadFile($vsBootstrapperUrl, $vsBootstrapperExe )
    } catch [System.Management.Automation.MethodInvocationException] {
        Write-Error "Unable to find Visual Studio bootstapper at $vsBootstrapperUrl."
    }
    if ((Test-Path $vsBootstrapperExe) -eq $false){
        Write-Error "Visual Studio bootstrapper ($vsBootstrapperUrl) not successfully download to $vsBootstrapperExe."
        return -1
    }
    StartAndWaitForProcess $vsBootstrapperExe "--quiet --update" @(0)

    #Get path to vs_installer.exe
    $vsInstallerExePath = (Get-ItemProperty -Path 'Registry::HKEY_LOCAL_MACHINE\SOFTWARE\WOW6432Node\Microsoft\Windows\CurrentVersion\Uninstall\{6F320B93-EE3C-4826-85E0-ADF79F8D4C61}' -Name 'InstallLocation').InstallLocation.Trim('"')
    $vsInstallExe = Join-Path $vsInstallerExePath  'vs_installer.exe'
    Write-Verbose "Visual Studio Installer is at $vsInstallExe"
  
   #Find VS Install Path(s) and add Service Fabric component.
   foreach ($VSInstallPathInfo in $vsInstallInfoArray){
        Write-Output "Enabling component for Service Fabric Tools for installation $($VSInstallPathInfo.InstallationPath)"
        StartAndWaitForProcess $vsInstallExe "modify --installPath `"$($VSInstallPathInfo.InstallationPath)`" --add Microsoft.VisualStudio.Component.Azure.ServiceFabric.Tools --add Microsoft.VisualStudio.Workload.Azure --quiet --norestart" @(0)
    }
}