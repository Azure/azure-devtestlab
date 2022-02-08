Param(
    [Parameter(Mandatory=$true)]
    [ValidateSet("2015","2017","2019","2022")] 
    [string] $version,

    [Parameter(Mandatory=$true)]
    [ValidateSet("Professional","Enterprise")] 
    [string] $sku,

    [Parameter()]
    [string] $installerArgs
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

# Ensure we force use of TLS 1.2 for all downloads.
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12

# Discard any collected errors from a previous execution.
$Error.Clear()

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

function DownloadToFilePath ($downloadUrl, $targetFile)
{
    Write-Output ("Downloading installation files from URL: $downloadUrl to $targetFile")
    $targetFolder = Split-Path $targetFile

    if ((Test-Path -path $targetFile))
    {
        Write-Output "Deleting old target file $targetFile"
        Remove-Item $targetFile -Force | Out-Null
    }

    if (-not (Test-Path -path $targetFolder))
    {
        Write-Output "Creating folder $targetFolder"
        New-Item -ItemType Directory -Force -Path $targetFolder | Out-Null
    }

    # Download the file, with retries.
    $downloadAttempts = 0
    do
    {
        $downloadAttempts++

        try
        {
            $WebClient = New-Object System.Net.WebClient
            $WebClient.DownloadFile($downloadUrl,$targetFile)
            break
        }
        catch
        {
            Write-Output "Caught exception during download..."
            if ($_.Exception.InnerException)
            {
                Write-Output "InnerException: $($_.InnerException.Message)"
            }
            else
            {
                Write-Output "Exception: $($_.Exception.Message)"
            }
        }

    } while ($downloadAttempts -lt 5)

    if ($downloadAttempts -eq 5)
    {
        Write-Error "Download of $downloadUrl failed repeatedly. Giving up."
    }
}

###################################################################################################
#
# Main execution block.
#

try
{
    Push-Location $PSScriptRoot

    Write-Output "Installing Visual Studio $version $sku"
    $logFolder = Join-path -path $env:ProgramData -childPath "DTLArt_VS"

    # Split the given installer arguments accounting for flags (i.e./Quiet), arguments with values (i.e. /Log $vsLog),
    # arguments with dashes (i.e. -Quiet) or even double dashes (i.e. --quiet), etc.
    [array]$installerArgsList = $installerArgs -split '(?<![\w|-])(?=\-)|(?<!\w)(?=/)' | ? { $_ -ne '' } | % { $_.trim() }
    if ($installerArgsList)
    {
        Write-Output "InstallerArgs value: $installerArgsList"
    }

    if ($version -eq '2015' )
    {
        $vsLog = Join-Path $logFolder "VSInstall.log"

        $argumentList = $installerArgsList + @(
            "/Quiet",
            "/NoRestart"
            "/Log $vsLog"
        )

        if ($sku -eq 'Professional')
        {
            $downloadUrl = 'http://go.microsoft.com/fwlink/?LinkId=615435'
        }
        elseif ($sku -eq 'Enterprise')
        {
            $downloadUrl = 'http://go.microsoft.com/fwlink/?LinkId=615437'
        }
    }
    elseif ($version -eq '2017')
    {
        $commonArgsList = @(
            "--includeRecommended",
            "--quiet",
            "--norestart",
            "--wait"
        )

        # Proffesional
        $proffesionalModulesArgsList = @(
            "--add Microsoft.VisualStudio.Workload.Azure",
            "--add Microsoft.VisualStudio.Workload.Data",
            "--add Microsoft.VisualStudio.Workload.ManagedDesktop",
            "--add Microsoft.VisualStudio.Workload.NativeDesktop",
            "--add Microsoft.VisualStudio.Workload.NetCoreTools",
            "--add Microsoft.VisualStudio.Workload.NetWeb"
        )

        # Enterprise (includes all proffesional modules)
        $enterpriseModulesArgsList = $proffesionalModulesArgsList + @(
            "--add Component.GitHub.VisualStudio",
            "--add Microsoft.VisualStudio.Component.TestTools.MicrosoftTestManager",
            "--add Microsoft.VisualStudio.Component.TestTools.WebLoadTest",
            "--add Microsoft.VisualStudio.Workload.NativeCrossPlat"
        )

        if ($sku -eq 'Professional')
        {
            $argumentList = $installerArgsList + $commonArgsList + $proffesionalModulesArgsList
            $downloadUrl = 'https://download.visualstudio.microsoft.com/download/pr/100196700/14dd70405e8244481b35017b9a562edd/vs_Professional.exe'
        }
        elseif ($sku -eq 'Enterprise')
        {
            $argumentList = $installerArgsList + $commonArgsList + $enterpriseModulesArgsList
            $downloadUrl = 'https://download.microsoft.com/download/F/3/4/F3478590-7B38-48B1-BB6E-3141A9A155E7/vs_Enterprise.exe'
        }
    }    
    elseif ($version -eq '2019')
    {
        $commonArgsList = @(
            "--includeRecommended",
            "--quiet",
            "--norestart",
            "--wait"
        )

        # Proffesional
        $proffesionalModulesArgsList = @(
            "--add Microsoft.VisualStudio.Workload.Azure",
            "--add Microsoft.VisualStudio.Workload.Data",
            "--add Microsoft.VisualStudio.Workload.ManagedDesktop",
            "--add Microsoft.VisualStudio.Workload.NativeDesktop",
            "--add Microsoft.VisualStudio.Workload.NetCoreTools",
            "--add Microsoft.VisualStudio.Workload.NetWeb"
        )

        # Enterprise (includes all proffesional modules)
        $enterpriseModulesArgsList = $proffesionalModulesArgsList + @(
            "--add Component.GitHub.VisualStudio",
            "--add Microsoft.VisualStudio.Component.TestTools.WebLoadTest",
            "--add Microsoft.VisualStudio.Workload.NativeCrossPlat"
        )

        if ($sku -eq 'Professional')
        {
            $argumentList = $installerArgsList + $commonArgsList + $proffesionalModulesArgsList
            $downloadUrl = 'https://aka.ms/vs/16/release/vs_professional.exe'
        }
        elseif ($sku -eq 'Enterprise')
        {
            $argumentList = $installerArgsList + $commonArgsList + $enterpriseModulesArgsList
            $downloadUrl = 'https://aka.ms/vs/16/release/vs_enterprise.exe'
        }
    }
    elseif ($version -eq '2022')
    {
        $commonArgsList = @(
            "--includeRecommended",
            "--quiet",
            "--norestart",
            "--wait"
        )

        # Proffesional
        $proffesionalModulesArgsList = @(
            "--add Microsoft.VisualStudio.Workload.Azure",
            "--add Microsoft.VisualStudio.Workload.Data",
            "--add Microsoft.VisualStudio.Workload.ManagedDesktop",
            "--add Microsoft.VisualStudio.Workload.NativeDesktop",
            "--add Microsoft.VisualStudio.Workload.NetWeb"
        )

        # Enterprise (includes all proffesional modules)
        $enterpriseModulesArgsList = $proffesionalModulesArgsList + @(
            "--add Component.GitHub.VisualStudio",
            "--add Microsoft.VisualStudio.Component.TestTools.WebLoadTest",
            "--add Microsoft.VisualStudio.Workload.NativeCrossPlat"
        )

        if ($sku -eq 'Professional')
        {
            $argumentList = $installerArgsList + $commonArgsList + $proffesionalModulesArgsList
            $downloadUrl = 'https://aka.ms/vs/17/release/vs_professional.exe'
        }
        elseif ($sku -eq 'Enterprise')
        {
            $argumentList = $installerArgsList + $commonArgsList + $enterpriseModulesArgsList
            $downloadUrl = 'https://aka.ms/vs/17/release/vs_enterprise.exe'
        }
    }
    else
    {
        throw "Version is not recognized - allowed values are 2015, 2017, 2019, and 2022. Specified value: $version"
    }

    $localFile = Join-Path $logFolder 'vsinstaller.exe'
    DownloadToFilePath $downloadUrl $localFile

    # Ensure there are no duplicate entries in the argument list.
    $argumentList = $argumentList | Select -Unique

    Write-Output "Running install with the following arguments: $argumentList"
    $retCode = Start-Process -FilePath $localFile -ArgumentList $argumentList -Wait -PassThru

    if ($retCode.ExitCode -ne 0 -and $retCode.ExitCode -ne 3010)
    {
        if($version -eq '2017')
        {
            $targetLogs = 'c:\VS2017Logs'
            New-Item -ItemType Directory -Force -Path $targetLogs | Out-Null
            Write-Output ('Temp location is ' + $env:TEMP)
            Copy-Item -path $env:TEMP\dd* -Destination $targetLogs
        }

        throw "Product installation of $localFile failed with exit code: $($retCode.ExitCode.ToString())"    
    }

    Write-Output "Visual Studio install succeeded. Rebooting..."

    Write-Host "`nThe artifact was applied successfully.`n"
}
finally
{
    Pop-Location
}
