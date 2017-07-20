﻿<##################################################################################################

    Description
    ===========

	- This script does the following - 
		- installs chocolatey
		- registers a chocolatey feed

	- This script generates logs in the following folder - 
		- %ALLUSERSPROFILE%\ChocolateyFeedInstaller-{TimeStamp}\Logs folder.


    Usage examples
    ==============
    
    Powershell -executionpolicy bypass -file ChocolateyFeedInstaller.ps1


    Pre-Requisites
    ==============

    - Ensure that the powershell execution policy is set to unrestricted (@TODO).


    Known issues / Caveats
    ======================
    
    - No known issues.


    Coming soon / planned work
    ==========================

    - N/A.    

##################################################################################################>

#
# Optional arguments to this script file.
#

Param(
    [string] $FeedName,
    [string] $FeedUrl,
    [string] $FeedUsername,
    [string] $FeedPassword,
    [boolean] $DisableDefault
)

##################################################################################################

#
# Powershell Configurations
#

# Note: Because the $ErrorActionPreference is "Stop", this script will stop on first failure.  
$ErrorActionPreference = "Stop"

# Ensure that current process can run scripts. 
Set-ExecutionPolicy -ExecutionPolicy Bypass -Scope Process -Force 

###################################################################################################

#
# Custom Configurations
#

$ChocolateyFeedInstallerFolder = Join-Path $env:ALLUSERSPROFILE -ChildPath $("ChocolateyFeedInstaller-" + [System.DateTime]::Now.ToString("yyyy-MM-dd-HH-mm-ss"))

# Location of the log files
$ScriptLog = Join-Path -Path $ChocolateyFeedInstallerFolder -ChildPath "ChocolateyFeedInstaller.log"
$ChocolateyInstallLog = Join-Path -Path $ChocolateyFeedInstallerFolder -ChildPath "ChocolateyInstall.log"

##################################################################################################

# 
# Description:
#  - Displays the script argument values (default or user-supplied).
#
# Parameters:
#  - N/A.
#
# Return:
#  - N/A.
#
# Notes:
#  - Please ensure that the Initialize() method has been called at least once before this 
#    method. Else this method can only write to console and not to log files. 
#

function DisplayArgValues
{
    WriteLog '========== Configuration =========='
    WriteLog "FeedName: $FeedName"
    WriteLog "FeedUrl: $FeedUrl"
    if ($FeedUsername) {
        WriteLog "FeedUsername: $FeedUsername"
        WriteLog "FeedPassword: $('*' * $FeedPassword.Length)"
    }
    WriteLog "DisableDefault: $DisableDefault"
    WriteLog '========== Configuration =========='
}

##################################################################################################

# 
# Description:
#  - Creates the folder structure which'll be used for dumping logs generated by this script and
#    the logon task.
#
# Parameters:
#  - N/A.
#
# Return:
#  - N/A.
#
# Notes:
#  - N/A.
#

function InitializeFolders
{
    if ($false -eq (Test-Path -Path $ChocolateyFeedInstallerFolder))
    {
        New-Item -Path $ChocolateyFeedInstallerFolder -ItemType directory | Out-Null
    }
}

##################################################################################################

# 
# Description:
#  - Writes specified string to the console as well as to the script log (indicated by $ScriptLog).
#
# Parameters:
#  - $message: The string to write.
#
# Return:
#  - N/A.
#
# Notes:
#  - N/A.
#

function WriteLog
{
    Param(
        <# Can be null or empty #>
        [string]$Message,
        [switch]$LogFileOnly
    )

    $timestampedMessage = "[$([System.DateTime]::Now)] $Message" | % {
        if (-not $LogFileOnly)
        {
            Write-Host -Object $_
        }
        Out-File -InputObject $_ -FilePath $ScriptLog -Append
    }
}

##################################################################################################

# 
# Description:
#  - Installs the chocolatey package manager.
#
# Parameters:
#  - N/A.
#
# Return:
#  - If installation is successful, then nothing is returned.
#  - Else a detailed terminating error is thrown.
#
# Notes:
#  - @TODO: Write to $chocolateyInstallLog log file.
#  - @TODO: Currently no errors are being written to the log file ($chocolateyInstallLog). This needs to be fixed.
#

function InstallChocolatey
{
    Param(
        [ValidateNotNullOrEmpty()] $chocolateyInstallLog
    )

    WriteLog 'Installing Chocolatey ...'

    Invoke-Expression ((new-object net.webclient).DownloadString('https://chocolatey.org/install.ps1')) | Out-Null

    WriteLog 'Success.'
}

##################################################################################################

#
# 
#

try
{
    #
    InitializeFolders

    #
    DisplayArgValues
    
    # install the chocolatey package manager
    InstallChocolatey -chocolateyInstallLog $ChocolateyInstallLog

    try {
        WriteLog -Message "Removing feed '$FeedName' ..."
        choco source remove --name "$FeedName"
    } catch {
        throw "Failed to remove chocolatey feed '$FeedName' - $($Error[0].Exception.Message)"
    }

    try {
        WriteLog -Message "Registering feed '$FeedName' ($FeedUrl) ..."
        if ($FeedUsername) {
            choco source add --name "$FeedName" --source "$FeedUrl" --user "$FeedUsername" --password "$FeedPassword"
        } else {
            choco source add --name "$FeedName" --source "$FeedUrl"
        }
    } catch {
        throw "Failed to add chocolatey feed '$FeedName' ($FeedUrl) - $($Error[0].Exception.Message)"
    }

    if ($DisableDefault) {        
        try {
            WriteLog -Message "Disabling default feed 'chocolatey' ..."
            choco source disable --name "chocolatey"
        } catch {
            throw "Failed to disable default chocolatey feed - $($Error[0].Exception.Message)"
        }
    }

    WriteLog -Message "done"
}
catch
{
    $errMsg = $Error[0].Exception.Message
    if ($errMsg)
    {
        WriteLog -Message "ERROR: $errMsg" -LogFileOnly
    }

    # IMPORTANT NOTE: We rely on startChocolatey.ps1 to manage the workflow. It is there where we need to
    # ensure an exit code is correctly sent back to the calling process. From here, all we need to do is
    # throw so that startChocolatey.ps1 can handle the state correctly.
    throw
}
