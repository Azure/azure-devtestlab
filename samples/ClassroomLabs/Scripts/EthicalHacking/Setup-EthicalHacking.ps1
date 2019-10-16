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

### Kali Linux Functions ###
<#
.SYNOPSIS
Downloads Kali Linux Hyper-V image and returns the path to the virtual machine configuration information file.
#>
function Get-KaliLinuxVmcxFile {
    $_kaliLinuxHyperVFilePath = "$env:PUBLIC\Documents\Hyper-V\Kali-Linux"
    New-Item -Path $_kaliLinuxHyperVFilePath -ItemType Directory -Force | Out-Null

    #If files already download, return
    $vmcxFilePath = Get-ChildItem "$_kaliLinuxHyperVFilePath\*.vmcx" -Recurse | Select-Object -expand FullName
    if ($null -ne $vmcxFilePath) { return $vmcxFilePath }
  
    Write-Host "Downloading compressed file with  Kali Linux image."
    #Download page is https://www.offensive-security.com/kali-linux-vm-vmware-virtualbox-image-download/
    $kaliLinux7ZipFile = Get-WebFile -DownloadUrl 'https://images.offensive-security.com/virtual-images/kali-linux-2019.3-hyperv-amd64.7z' -TargetFilePath $(Join-Path $env:TEMP 'KaliLinuxZip.7z') -SkipIfAlreadyExists $true
 
    Write-Host "Extracting Kali Linux Hyper-V files from compressed file."
    $sevenZipExe = Join-Path $env:ProgramFiles '7-zip\7z.exe'
    if (-not (Test-Path $sevenZipExe)) {
        #Download page is https://www.7-zip.org/download.html.
        $sevenZipInstallerPath = Get-WebFile -DownloadUrl 'https://www.7-zip.org/a/7z1900-x64.msi' -TargetFilePath $(Join-Path $env:TEMP '7zip.msi') -SkipIfAlreadyExists $true
  
        Invoke-Process -FileName "msiexec.exe" -Arguments "/i $sevenZipInstallerPath /quiet"
    }
          
    Invoke-Process -FileName $sevenZipExe -Arguments "x $kaliLinux7ZipFile -o$_kaliLinuxHyperVFilePath -r"
    
    return Get-ChildItem "$_kaliLinuxHyperVFilePath\*.vmcx" -Recurse | Select-Object -expand FullName
}

<#
.SYNOPSIS
Creates new Kali Linux Hyper-V virtual machine.
#>
function New-KaliLinuxVM {
    #if the machine already exists, return
    If ($null -ne (@(Get-VM) | Where-Object Name -Like "kali-linux*")) { return }

    $kaliLinuxVmcxFilePath = Get-KaliLinuxVmcxFile


    #fix ethernet adapter first, then import image
    Write-Host "Importing Kali Linux Hyper-V virtual machine."
    $report = Compare-Vm -Path $kaliLinuxVmcxFilePath
    $report.Incompatibilities[0].Source | Disconnect-VMNetworkAdapter 
    $report.VM | Add-VMNetworkAdapter -SwitchName $SwitchName
    import-vm -CompatibilityReport $report 

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
    #Download page is https://information.rapid7.com/download-metasploitable-2017.html
    $metasploitableZipFile = Get-WebFile -DownloadUrl 'http://downloads.metasploit.com/data/metasploitable/metasploitable-linux-2.0.0.zip' -TargetFilePath $(Join-Path $env:TEMP 'metasploitable-linux-2.0.0.zip') -SkipIfAlreadyExists $true
 
    Write-Host "Extracting Metasploitable image files."
    if ($null -eq (Get-ChildItem "$env:TEMP\*.vmdk" -Recurse | Select-Object -expand FullName)) {
        Expand-Archive $metasploitableZipFile -DestinationPath $env:TEMP
    }
    
    #install tools to convert vmdk file
    if ($null -eq (Get-WmiObject Win32_Product | Where-Object { $_.Name -match 'Microsoft Virtual Machine Converter' })) {
        #Main download page is at https://www.microsoft.com/en-us/download/details.aspx?id=42497
        $mvmcInstallerPath = Get-WebFile -DownloadUrl 'https://download.microsoft.com/download/9/1/E/91E9F42C-3F1F-4AD9-92B7-8DD65DA3B0C2/mvmc_setup.msi' -TargetFilePath $(Join-Path $env:TEMP 'mvmc_setup.msi')
        
        Invoke-Process -FileName "msiexec.exe" -Arguments "/i $mvmcInstallerPath /quiet" 
    }
    Import-Module "$env:ProgramFiles\Microsoft Virtual Machine Converter\MvmcCmdlet.psd1"

    #convert vmdk file
    Write-Host "Converting Metasploitable image files to Hyper-V hard disk file.  Warning: This may take several minutes."
    $vmdkFile = Get-ChildItem "$env:TEMP\*.vmdk" -Recurse | Select-Object -expand FullName
    #todo: test to make sure this returns
    ConvertTo-MvmcVirtualHardDisk -SourceLiteralPath $vmdkFile -DestinationLiteralPath $vhdxPath -VhdType DynamicHardDisk -VhdFormat vhdx | Out-Host

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
    Write-Host "Creating Metasploitable virtual machine."
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

    Write-Host "Verifying virtual machine switch '$SwitchName' exists."
    if ($null -eq (@(Get-VMSwitch) | Where-Object Name -like $SwitchName)) {
        Write-Error "Virtual machine doesn't exist.  Please create switch with name '$SwitchName'.  Try '../HyperV/SetupForNestedVirtualization.ps1 to create switch."
    }
 
    Write-Host "Creating Kali Linux virtual machine."
    New-KaliLinuxVM

    Write-Host "Creating Metasploitable Linux virtual machine."
    New-MetasploitableVm

    Write-Host -Object "Script completed." -ForegroundColor Green
}
finally {
    # Restore system to state prior to execution of this script.
    Pop-Location
}
