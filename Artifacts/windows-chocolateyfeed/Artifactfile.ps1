<##################################################################################################

    Description
    ===========

	Bootstrap for ensuring pre-requisites are validated prior to registering a new chocolatey feed.

    Pre-Requisites
    ==============

    - Ensure that the PowerShell execution policy is set to unrestricted.
    - If calling from another process, make sure to execute as script to get the exit code (e.g. "& ./foo.ps1 ...").

    artifactfile.json usage
    =======================

    To correctly report exit codes, make sure to structure the "commandToExecute" as follow:
    
    "commandToExecute": "[concat('powershell.exe -ExecutionPolicy bypass \"& ./Artifactfile.ps1 -FeedName ''', parameters('feedName'), ''' -FeedUrl ''', parameters('feedUrl'), ''' -Username ''', parameters('username'), ''' -Password ''', parameters('password'), ''' -DisableDefault ''', parameters('disableDefault'), '''\"')]"

    Known issues / Caveats
    ======================
    
    - Using powershell.exe's -File parameter may incorrectly return 0 as exit code, causing the
      operation to report success, even when it fails.

    Coming soon / planned work
    ==========================

    - N/A.    

##################################################################################################>

#
# Optional parameters to this script file.
#

[CmdletBinding()]
param (

    [string] $FeedName,
    [string] $FeedUrl,
    [string] $FeedUsername,
    [string] $FeedPassword,
    [boolean] $DisableDefault,
    
    [Parameter(ParameterSetName='CustomUser')]
    [string] $UserName = 'artifactInstaller',
    [Parameter(ParameterSetName='CustomUser')]
    [string] $Password,
    
    [int] $PSVersionRequired = 3
)

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

function Validate-Params
{
    [CmdletBinding()]
    param(
    )

    if ([string]::IsNullOrEmpty($FeedName))
    {
        throw 'FeedName parameter is required.'
    }
    elseif ($FeedName -ieq "chocolatey") 
    {
        throw 'The FeedName "chocolatey" is not allowed.'
    }
    if ([string]::IsNullOrEmpty($FeedUrl))
    {
        throw 'FeedUrl parameter is required.'
    }
    
    if ($FeedUsername -and [string]::IsNullOrEmpty($FeedPassword))
    {
        throw 'FeedPassword parameter is required, if a FeedUsername is given.'
    }

    if ($PsCmdlet.ParameterSetName -eq 'CustomUser')
    {
        if ([string]::IsNullOrEmpty($UserName))
        {
            throw 'UserName parameter is required when Password is specified.'
        }
        if ([string]::IsNullOrEmpty($Password))
        {
            throw 'Password parameter is required when UserName is specified.'
        }
    }
}

function Ensure-PowerShell
{
    [CmdletBinding()]
    param(
        [int] $Version
    )

    if ($PSVersionTable.PSVersion.Major -lt $Version)
    {
        throw "The current version of PowerShell is $($PSVersionTable.PSVersion.Major). Prior to running this artifact, ensure you have PowerShell $Version or higher installed."
    }
}

function Get-TempPassword
{
    [CmdletBinding()]
    param(
        [int] $length = 43
    )

    $sourceData = $null
    33..126 | % { $sourceData +=,[char][byte]$_ }

    1..$length | % { $tempPassword += ($sourceData | Get-Random) }

    return $tempPassword
}

function Add-LocalAdminUser
{
    [CmdletBinding()]
    param(
        [string] $UserName,
        [string] $Password,
        [string] $Description = 'DevTestLab artifact installer',
        [switch] $Overwrite = $true
    )
    
    if ($Overwrite)
    {
        Remove-LocalAdminUser -UserName $UserName
    }

    $computer = [ADSI]"WinNT://$env:ComputerName"
    $user = $computer.Create("User", $UserName)
    $user.SetPassword($Password)
    $user.Put("Description", $Description)
    $user.SetInfo()

    $group = [ADSI]"WinNT://$env:ComputerName/Administrators,group"
    $group.add("WinNT://$env:ComputerName/$UserName")
    
    return $user
}

function Remove-LocalAdminUser
{
    [CmdletBinding()]
    param(
        [string] $UserName
    )

    if ([ADSI]::Exists('WinNT://./' + $UserName))
    {
        $computer = [ADSI]"WinNT://$env:ComputerName"
        $computer.Delete('User', $UserName)
        try
        {
            gwmi win32_userprofile | ? { $_.LocalPath -like "*$UserName*" -and -not $_.Loaded } | % { $_.Delete() | Out-Null }
        }
        catch
        {
            # Ignore any errors, specially with locked folders/files. It will get cleaned up at a later time, when another artifact is installed.
        }
    }
}

function Set-LocalAccountTokenFilterPolicy
{
    [CmdletBinding()]
    param(
        [int] $Value = 1
    )

    $oldValue = 0

    $regPath ='HKLM:\Software\Microsoft\Windows\CurrentVersion\Policies\System'
    $policy = Get-ItemProperty -Path $regPath -Name LocalAccountTokenFilterPolicy -ErrorAction SilentlyContinue

    if ($policy)
    {
        $oldValue = $policy.LocalAccountTokenFilterPolicy
    }

    if ($oldValue -ne $Value)
    {
        Set-ItemProperty -Path $regPath -Name LocalAccountTokenFilterPolicy -Value $Value
    }

    return $oldValue
}

function Invoke-ChocolateyFeedInstaller
{
    [CmdletBinding()]
    param(
        [string] $UserName,
        [string] $Password,
        [object[]] $Arguments
    )

    $secPassword = ConvertTo-SecureString -String $Password -AsPlainText -Force
    $credential = New-Object System.Management.Automation.PSCredential("$env:COMPUTERNAME\$($UserName)", $secPassword)
    $command = "$PSScriptRoot\ChocolateyFeedInstaller.ps1"

    $oldPolicyValue = Set-LocalAccountTokenFilterPolicy
    try
    {
        Invoke-Command -ComputerName $env:COMPUTERNAME -Credential $credential -FilePath $command -ArgumentList $Arguments
    }
    finally
    {
        Set-LocalAccountTokenFilterPolicy -Value $oldPolicyValue | Out-Null
    }
}

###################################################################################################

#
# PowerShell configurations
#

# NOTE: Because the $ErrorActionPreference is "Stop", this script will stop on first failure.
#       This is necessary to ensure we capture errors inside the try-catch-finally block.
$ErrorActionPreference = "Stop"

###################################################################################################

#
# Main execution block.
#

try
{
    Validate-Params

    Ensure-PowerShell -Version $PSVersionRequired
    Enable-PSRemoting -Force -SkipNetworkProfileCheck

    if ($PsCmdlet.ParameterSetName -ne 'CustomUser')
    {
        $Password = Get-TempPassword
        Add-LocalAdminUser -UserName $UserName -Password $password | Out-Null
    }

    Invoke-ChocolateyFeedInstaller -UserName $UserName -Password $Password -Arguments ($FeedName, $FeedUrl, $FeedUsername, $FeedPassword, $DisableDefault)
}
catch
{
    Handle-LastError
}
finally
{
    if ($PsCmdlet.ParameterSetName -ne 'CustomUser')
    {
        Remove-LocalAdminUser -UserName $UserName
    }
}
