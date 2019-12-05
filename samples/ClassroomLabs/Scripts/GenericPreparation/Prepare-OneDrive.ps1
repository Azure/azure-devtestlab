<#
.SYNOPSIS
This script prepares a the OneDrive install for a Windows 10 machine for a generic class.  This includes installing the client, prompting to move known folders to OneDrive and automatically signed user into OneDrive, if possible.
.PARAMETER TenantId
The Tenant Id for your Office 365 subscription.
.NOTES
One way to get your TenantID is to run the following commands:
    Install-Module MSOnline 
    Connect-MsolService 
    Get-MSOLCompanyInformation | select -expand objectID | select -expand Guid  
If the above command fails, you can attempt to retrieve your Office Tenant ID from https://docs.microsoft.com/onedrive/find-your-office-365-tenant-id 
#>

[CmdletBinding()]
param( 
    [string]$TenantId
)

###################################################################################################
#
# PowerShell configurations
#

# NOTE: Because the $ErrorActionPreference is "Stop", this script will stop on first failure.
#       This is necessary to ensure we capture errors inside the try-catch-finally block.
$ErrorActionPreference = "Stop"

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

    exit -1
}

###################################################################################################
#
# Generic Functions
#             

<#
.SYNOPSIS
Returns true is script is running with administrator privileges and false otherwise.
#>
function Get-RunningAsAdministrator {
    [CmdletBinding()]
    param()
    
    $isAdministrator = ([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole] "Administrator")
    $null = @(
        Write-Verbose "Running with$(if(-not $isAdministrator) {"out"}) Administrator privileges."
    )
    return $isAdministrator
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

###################################################################################################
#
# Script Specific Functions
#    

<#
.SYNOPSIS
Download and install OneDrive for Business client application.
#>
function Install-OneDriveClient{
    #Disable the tutorial that shows at the end of the OneDrive Setup
    New-Item -Path "HKLM:\SOFTWARE\Policies\Microsoft\OneDrive" -Force | Out-Null
    New-ItemProperty -Path "HKLM:\SOFTWARE\Policies\Microsoft\OneDrive" -Name "DisableTutorial" -Value "00000001" -PropertyType DWORD -Force | Out-Null
    
    $onedriveSetupExePath = "$env:userprofile/Downloads/OneDriveSetup.exe"
    Get-WebFile -DownloadUrl "https://go.microsoft.com/fwlink/p/?LinkId=248256" -TargetFilePath $onedriveSetupExePath -SkipIfAlreadyExists $true
    Invoke-Process -FileName $onedriveSetupExePath -Arguments '/allUsers /silent'   
}

<#
.SYNOPSIS
Turn on prompt that helps user move their known folders (Documents, Pictures, etc) to OneDrive.
#>
function Set-PromptToMoveKnownFoldersToOneDrive{
    param([Parameter(Mandatory=$true)][string] $tenantId)
     
    New-Item -Path "HKLM:\SOFTWARE\Policies\Microsoft\OneDrive" -Force | Out-Null
    New-ItemProperty -Path "HKLM:\SOFTWARE\Policies\Microsoft\OneDrive" -Name "KFMOptInWithWizard" -Value $tenantId -PropertyType String -Force | Out-Null
}

<#
.SYNOPSIS
Download and install OneDrive for Business client application.
.PARAMETER TenantId
Tenant Id for Office 365 subscription.
.PARAMETER size
Maximum size of file to allow to be uploaded to OneDrive.  
#>
function Set-OneDriveFileMaximumSize{
    param(
        [Parameter(Mandatory=$true)][string] $tenantId,
        [string] $size = "0005000" #5 GB
        )

    New-Item -Path "HKLM:\SOFTWARE\Policies\Microsoft\OneDrive" -Force | Out-Null 
    New-Item -Path "HKLM:\SOFTWARE\Policies\Microsoft\OneDrive\DiskSpaceCheckThresholdMB" -Force | Out-Null
    New-ItemProperty -Path "HKLM:\SOFTWARE\Policies\Microsoft\OneDrive\DiskSpaceCheckThresholdMB" -Name $tenantId -Value $size -PropertyType DWORD -Force | Out-Null

}

<#
.SYNOPSIS
Set OneDrive to download files on demand
#>
function Set-OneDriveDownloadFilesOnDemand{
    New-Item -Path "HKLM:\SOFTWARE\Policies\Microsoft\OneDrive" -Force | Out-Null
    New-ItemProperty -Path "HKLM:\SOFTWARE\Policies\Microsoft\OneDrive" -Name "FilesOnDemandEnabled" -Value "00000001" -PropertyType DWORD -Force | Out-Null
}

<#
.SYNOPSIS
Set OneDrive to sign in with windows credentials.
#>
function Set-SignIntoOneDriveWithDomainCreds{
    New-Item -Path "HKLM:\SOFTWARE\Policies\Microsoft\OneDrive" -Force | Out-Null
    New-ItemProperty -Path "HKLM:\SOFTWARE\Policies\Microsoft\OneDrive" -Name "SilentAccountConfig" -Value "00000001" -PropertyType DWORD -Force | Out-Null
}


###################################################################################################
#
# Main execution block.
#

try {
    Write-Host "Verifying running as administrator."
    if (-not (Get-RunningAsAdministrator)) { 
        Write-Error "Please re-run this script as Administrator." 
    }

    Install-OneDriveClient

    Set-OneDriveDownloadFilesOnDemand

    if ((gwmi win32_computersystem).partofdomain -eq $true) {
        Set-SignIntoOneDriveWithWindowCreds
    } else {
        Write-Host "Computer is not joined to domain.  OneDrive will not be set to use windows credentials for login."
    }

    if ([String]::IsNullOrEmpty($TenantId) -eq $false)
    {
        Set-PromptToMoveKnownFoldersToOneDrive -tenantId $TenantId
        Set-OneDriveFileMaximumSize -tenantId $TenantId
    }else {
        Write-Host 'Warning: Tenant Id not specified. User will not will not be prompted to move known folders to OneDrive.' -ForegroundColor 'Yellow'
        Write-Host 'Warning: Tenant Id not specified. Maximum size for synced files will not be set.' -ForegroundColor 'Yellow'
    }

    Write-Host -Object "Script completed successfully." -ForegroundColor Green
}
finally {
    # Restore system to state prior to execution of this script.
    Pop-Location
}
