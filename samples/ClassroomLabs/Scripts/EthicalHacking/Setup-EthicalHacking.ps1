 <#
The MIT License (MIT)
Copyright (c) Microsoft Corporation  
Permission is hereby granted, free of charge, to any person obtaining a copy of this software and associated documentation files (the "Software"), to deal in the Software without restriction, including without limitation the rights to use, copy, modify, merge, publish, distribute, sublicense, and/or sell copies of the Software, and to permit persons to whom the Software is furnished to do so, subject to the following conditions:
The above copyright notice and this permission notice shall be included in all copies or substantial portions of the Software.  
THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE. 
.SYNOPSIS
This script prepares a Windows Server machine for an ethical hacking class.  It creates a Kali Linux virtual machine with tools for penetration testing and Metasploitable Linux virthal machine with vulnerabilities intentionally created in the image.  Virtual machines are on the same network.
.PARAMETER SwitchName
The name of the virtual switch to which the virtual machines should be connected.  By default, this script uses the switch created when ../HyperV/SetupForNestedVirtualization.ps1 is executed.
#>

[CmdletBinding()]
param(
    [string]$SwitchName = "LabServicesSwitch"
)

###################################################################################################
#
# PowerShell configurations
#

# NOTE: Because the $ErrorActionPreference is "Stop", this script will stop on first failure.
#       This is necessary to ensure we capture errors inside the try-catch-finally block.
$ErrorActionPreference = "Stop"

# Hide any progress bars, due to downloads and installs of remote components.
$ProgressPreference = "SilentlyContinue"

# Ensure we set the working directory to that of the script.
Push-Location $PSScriptRoot

# Discard any collected errors from a previous execution.
$Error.Clear()

# Configure strict debugging.
Set-PSDebug -Strict

###################################################################################################
#
# Handle all errors in this script.
#

trap {
    # NOTE: This trap will handle all errors. There should be no need to use a catch below in this
    #       script, unless you want to ignore a specific error.
    $message = $Error[0].Exception.Message
    if ($message) {
        Write-Host -Object "`nERROR: $message" -ForegroundColor Red
    }

    Write-Host "`nThe script failed to run.`n"

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

<#
.SYNOPSIS
Returns true is script is running with administrator privileges and false otherwise.
#>
function Get-RunningAsAdministrator {
    [CmdletBinding()]
    param()
    
    $isAdministrator = ([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole] "Administrator")
    Write-Verbose "Running with Administrator privileges (t/f): $isAdministrator"
    return $isAdministrator
}

<#
.SYNOPSIS
Returns true is current machine is a Windows Server machine and false otherwise.
#>
function Get-RunningServerOperatingSystem {
    [CmdletBinding()]
    param()

    return ($null -ne $(Get-Module -ListAvailable -Name 'servermanager') )
}

<#
.SYNOPSIS
Funtion will download file from specified url.
.PARAMETER DownloadUrl
Url where to get file.
.PARAMETER TargetFilePath
Path where download file will be saved.
.PARAMETER SkipIfAlreadyExists
Skip download if TargetFilePath already exists.
#>
function Get-WebFile {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)][string]$DownloadUrl ,
        [Parameter(Mandatory = $true)][string]$TargetFilePath,
        [Parameter(Mandatory = $false)][bool]$SkipIfAlreadyExists = $true
    )

    Write-Verbose ("Downloading installation files from URL: $DownloadUrl to $TargetFilePath")
    $targetFolder = Split-Path $TargetFilePath

    #See if file already exists and skip download if told to do so
    if ($SkipIfAlreadyExists -and (Test-Path $TargetFilePath)) {
        Write-Verbose "File $TargetFilePath already exists.  Skipping download."
        return $TargetFilePath
        
    }

    #Make destination folder, if it doesn't already exist
    if ((Test-Path -path $targetFolder) -eq $false) {
        Write-Verbose "Creating folder $targetFolder"
        New-Item -ItemType Directory -Force -Path $targetFolder | Out-Null
    }

    #Download the file
    for ($i = 1; $i -le 5; $i++) {
        try {
            [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12 ; # Enable TLS 1.2 as Security Protocol
            $WebClient = New-Object System.Net.WebClient
            $WebClient.DownloadFile($DownloadUrl, $TargetFilePath)
            Write-Verbose "File $TargetFilePath download."
            return $TargetFilePath
        }
        catch [Exception] {
            Write-Verbose "Caught exception during download..."
            if ($_.Exception.InnerException) {
                $exceptionMessage = $_.InnerException.Message
                Write-Verbose "InnerException: $exceptionMessage"
            }
            else {
                $exceptionMessage = $_.Message
                Write-Verbose "Exception: $exceptionMessage"
            }
        }
    }
    Write-Error "Download of $DownloadUrl failed $i times. Aborting download."
}

<#
.SYNOPSIS
Invokes process and waits for process to exit.
.PARAMETER FileName
Name of executable file to run.  This can be full path to file or file available through the system paths.
.PARAMETER Arguments
Arguments to pass to executable file.
.PARAMETER ValidExitCodes
List of valid exit code when process ends.  By default 0 and 3010 (restart needed) are accepted.
#>
function Invoke-Process {
    [CmdletBinding()]
    param (
        [string] $FileName = $(throw 'The FileName must be provided'),
        [string] $Arguments = '',
        [Array] $ValidExitCodes = @()
    )

    Write-Host "Running command '$FileName $Arguments'"

    # Prepare specifics for starting the process that will install the component.
    $startInfo = New-Object System.Diagnostics.ProcessStartInfo -Property @{
        Arguments              = $Arguments
        CreateNoWindow         = $true
        ErrorDialog            = $false
        FileName               = $FileName
        RedirectStandardError  = $true
        RedirectStandardInput  = $true
        RedirectStandardOutput = $true
        UseShellExecute        = $false
        Verb                   = 'runas'
        WindowStyle            = [System.Diagnostics.ProcessWindowStyle]::Hidden
        WorkingDirectory       = $PSScriptRoot
    }

    # Initialize a new process.
    $process = New-Object System.Diagnostics.Process
    try {
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
        if ($process.Start()) {
            # Read from all redirected streams before waiting to prevent deadlock.
            $process.BeginErrorReadLine()
            $process.BeginOutputReadLine()
            # Wait for the application to exit for no more than 5 minutes.
            $process.WaitForExit(300000) | Out-Null
        }
        # Ensure we extract an exit code, if not from the process itself.
        $exitCode = $process.ExitCode
        # Determine if process requires a reboot.
        if ($exitCode -eq 3010) {
            Write-Host 'The recent changes indicate a reboot is necessary. Please reboot at your earliest convenience.'
        }
        elseif ($ValidExitCodes.Contains($exitCode)) {
            Write-Host "$FileName exited with expected valid exit code: $exitCode"
            # Override to ensure the overall script doesn't fail.
            $LASTEXITCODE = 0
        }
        # Determine if process failed to execute.
        elseif ($exitCode -gt 0) {
            # Throwing an exception at this point will stop any subsequent
            # attempts for deployment.
            throw "$FileName exited with code: $exitCode"
        }
    }
    finally {
        # Free all resources associated to the process.
        $process.Close();
        # Remove any previous event handlers.
        Unregister-Event OnErrorDataReceived -Force | Out-Null
        Unregister-Event OnOutputDataReceived -Force | Out-Null
    }
}

<#
.SYNOPSIS
Funtion will convert from .vmdk to .vhdx Hyper-V hard disk file.
.PARAMETER VmdkFilePath
Full file path for vmdk to be converted.
.PARAMETER VhdxFilePath
File file path where vhdx file should be created.
#>
function Convert-VdmkToVhdx {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory=$true)][string] $VmdkFilePath,
        [Parameter(Mandatory=$true)][string] $VhdxFilePath
    )
    
    Write-Host "Finding Starwind V2V Converter executable"
    $swcExePath = Join-Path $env:ProgramFiles 'StarWind Software\StarWind V2V Converter\V2V_ConverterConsole.exe'
    if (-not (Test-Path $swcExePath)){
        Write-Host "Installing Starwind V2V Converter"
        #Main download page is at https://www.starwindsoftware.com/download-starwind-products#download, choose 'Starwind V2V Converter'.
        Invoke-Process -FileName $(Get-WebFile -DownloadUrl 'https://www.starwindsoftware.com/tmplink/starwindconverter.exe' -TargetFilePath $(Join-Path $env:TEMP 'starwindconverter.exe')) -Arguments '/verysilent'
    }

    #convert vmdk file
    Write-Host "Converting '$VmdkFilePath' to '$VhdxFilePath'.  Warning: This may take several minutes."
    Invoke-Process -FileName $swcExePath -Arguments "convert in_file_name=""$VmdkFilePath"" out_file_name=""$VhdxFilePath"" out_file_type=ft_vhdx_thin"
}

### Kali Linux Functions ###
<#
.SYNOPSIS
Downloads Kali Linux Hyper-V image and returns the path to the virtual machine configuration information file.
#>
function Get-KaliLinuxDisk {
    $vhdxPath = "$env:PUBLIC\Documents\Hyper-V\Virtual hard disks\Kali-Linux-2020.4-vmware-amd64.vhdx"

    if (Test-Path ($vhdxPath)) { return $vhdxPath }

    Write-Host "Downloading Kali Linux image compressed file. "
     $_kaliLinuxExtractedFilesFolder = Join-Path $env:TEMP 'KaliLinux'
    #Download page is https://www.kali.org/get-kali/#kali-virtual-machines
    $_kaliDownloadedFileName = 'kali-linux-2021.4-vmware-amd64.7z'
    $kaliLinux7ZipFile = Get-WebFile -DownloadUrl 'https://kali.download/virtual-images/kali-2021.4/kali-linux-2021.4-vmware-amd64.7z' -TargetFilePath $(Join-Path $_kaliLinuxExtractedFilesFolder $_kaliDownloadedFileName) -SkipIfAlreadyExists $true
 
    $sevenZipExe = Join-Path $env:ProgramFiles '7-zip\7z.exe'
    if (-not (Test-Path $sevenZipExe)) {
        Write-Host "Downloading and installing 7-Zip to extract Kali Linux compressed files."
          #Download page is https://www.7-zip.org/download.html.
        $sevenZipInstallerPath = Get-WebFile -DownloadUrl 'https://www.7-zip.org/a/7z1900-x64.msi' -TargetFilePath $(Join-Path $env:TEMP '7zip.msi') -SkipIfAlreadyExists $true
  
        Invoke-Process -FileName "msiexec.exe" -Arguments "/i $sevenZipInstallerPath /quiet"
    }

    Write-Host "Extracting Kali Linux files from compressed file."
    if ($null -eq (Get-ChildItem "$_kaliLinuxExtractedFilesFolder\Kali-Linux-2021.4-vmware-amd64.vmwarevm" -Recurse | Select-Object -expand FullName)) {
        Invoke-Process -FileName $sevenZipExe -Arguments "x $kaliLinux7ZipFile -o$_kaliLinuxExtractedFilesFolder -r"
    }
    $vmdkFile = Get-ChildItem "$_kaliLinuxExtractedFilesFolder\Kali-Linux-2021.4-vmware-amd64.vmwarevm\Kali-Linux-2021.4-vmware-amd64.vmdk" -Recurse | Select-Object -expand FullName
    Write-Verbose "VmdkFile path: $vmdkFile"

    Write-Host "Converting downloading Kali Linux files to Hyper-V files."
    Convert-VdmkToVhdx -VmdkFilePath $vmdkFile -VhdxFilePath $vhdxPath

    return $vhdxPath
}

<#
.SYNOPSIS
Creates new Kali Linux Hyper-V virtual machine.
#>
function New-KaliLinuxVM {
    $computerName = 'kali-linux'

    #if the machine already exists, with expected network adapter, return
    If ($null -ne (@(Get-VM) | Where-Object Name -Like $computerName | Get-VMNetworkAdapter | Where-Object SwitchName -like $SwitchName)) { return }

    #download virtual hard disk, if not down already.
    $kaliLinuxHardDiskFilePath = Get-KaliLinuxDisk

    #create-vm, add network adapter (legacy)
    Write-Host "Looking for Kali Linux virtual machine.  Virtual machine will be created if not found."
    $vm = @(Get-VM) | Where-Object Name -Like $computerName
    if ($null -eq $vm) {
        $vm = New-VM -Name $computerName -MemoryStartupBytes 2048MB -VHDPath $kaliLinuxHardDiskFilePath 
    }
    Write-Host "Adding network adapter to Kali Linux virtual machine."
    if ($null -eq ($vm | Get-VMNetworkAdapter | Where-Object SwitchName -like $SwitchName)) {
        $vm | Add-VMNetworkAdapter -SwitchName $SwitchName -IsLegacy $true
    }
}

### Metasploitable Functions ###
<#
.SYNOPSIS
Downloads Metasploitable image files and converts disk file to Hyper-V virtual hard disk file.  Path to converted disk file is returned.
#>
function Get-MetasploitableDisk {
    $vhdxPath = "$env:PUBLIC\Documents\Hyper-V\Virtual hard disks\Metasploitable.vhdx"

    if (Test-Path ($vhdxPath)) { return $vhdxPath }

    Write-Host "Downloading Metasploitable image compressed file. "
    $_metasploitableLinuxExtractPath = Join-Path $env:Temp 'MetasploitableLinux'
    #Download page is https://information.rapid7.com/download-metasploitable-2017.html
    $metasploitableZipFile = Get-WebFile -DownloadUrl 'http://downloads.metasploit.com/data/metasploitable/metasploitable-linux-2.0.0.zip' -TargetFilePath $(Join-Path $_metasploitableLinuxExtractPath 'metasploitable-linux-2.0.0.zip') -SkipIfAlreadyExists $true
 
    Write-Host "Extracting Metasploitable image files."
    if ($null -eq (Get-ChildItem "$_metasploitableLinuxExtractPath\*.vmdk" -Recurse | Select-Object -expand FullName)) {
        Expand-Archive $metasploitableZipFile -DestinationPath $_metasploitableLinuxExtractPath
    }
    $vmdkFile = Get-ChildItem "$_metasploitableLinuxExtractPath\*.vmdk" -Recurse | Select-Object -expand FullName

    Write-Host "Converting downloaded Metasploitable Linux files to Hyper-V files."
    Convert-VdmkToVhdx -VmdkFilePath $vmdkFile -VhdxFilePath $vhdxPath

    return $vhdxPath
}

<#
.SYNOPSIS
Creates new Metasploitable Linux virtual machine.
#>
function New-MetasploitableVm {
    $metasploitableComputerName = 'metasploitable'

    #if the machine already exists, with expected network adapter, return
    If ($null -ne (@(Get-VM) | Where-Object Name -Like $metasploitableComputerName | Get-VMNetworkAdapter | Where-Object SwitchName -like $SwitchName)) { return }

    #download files, if not done already
    $metasploitableHardDiskFilePath = Get-MetasploitableDisk
   
    #create-vm, add network adapter (legacy)
    Write-Host "Looking for Metasploitable virtual machine.  Virtual machine will be created if not found."
    $vm = @(Get-VM) | Where-Object Name -Like $metasploitableComputerName
    if ($null -eq $vm) {
        $vm = New-VM -Name $metasploitableComputerName -MemoryStartupBytes 512MB -VHDPath $metasploitableHardDiskFilePath 
    }
    Write-Host "Adding network adapter to Metasploitable virtual machine."
    if ($null -eq ($vm | Get-VMNetworkAdapter | Where-Object SwitchName -like $SwitchName)) {
        $vm | Add-VMNetworkAdapter -SwitchName $SwitchName -IsLegacy $true
    }
}

###################################################################################################
#
# Main execution block.
#

try {
    Write-Host "Verifying server operating system."
    if (-not (Get-RunningServerOperatingSystem)) { 
        Write-Error "This script is designed to run on Windows Server." 
    }

    Write-Host "Verifying running as administrator."
    if (-not (Get-RunningAsAdministrator)) { 
        Write-Error "Please re-run this script as Administrator." 
    }

    Write-Host "Verifying Hyper-V enabled."
    if ($null -eq $(Get-WindowsFeature -Name 'Hyper-V')) {
        Write-Error "This script only applies to machines that can run Hyper-V."
    }
    if (([Microsoft.Windows.ServerManager.Commands.InstallState]::Installed -ne $(Get-WindowsFeature -Name 'Hyper-V' | Select-Object -ExpandProperty 'InstallState')) -or
        ($null -eq (Get-Command Get-VMSwitch -errorAction SilentlyContinue))) {
        Write-Error "This script only applies to machines that have Hyper-V feature and tools installed.  Try '../HyperV/SetupForNestedVirtualization.ps1 to install."
    }

    Write-Host "Verifying virtual machine switch '$SwitchName' exists."
    if ($null -eq (@(Get-VMSwitch) | Where-Object Name -like $SwitchName)) {
        Write-Error "Virtual machine doesn't exist.  Please create switch with name '$SwitchName' or specify switch name in script arguments.  Try '../HyperV/SetupForNestedVirtualization.ps1 to create switch."
    }
 
    Write-Host "Creating Kali Linux virtual machine, if needed."
    New-KaliLinuxVM

    Write-Host "Creating Metasploitable Linux virtual machine, if needed."
    New-MetasploitableVm

    Write-Host -Object "Script completed." -ForegroundColor Green
}
finally {
    # Restore system to state prior to execution of this script.
    Pop-Location
}
