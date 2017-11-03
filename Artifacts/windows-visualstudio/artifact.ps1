Param(
    [Parameter(Mandatory=$true)]
    [ValidateSet("2015","2017")] 
    [string] $version,

    [Parameter(Mandatory=$true)]
    [ValidateSet("Professional","Enterprise")] 
    [string] $sku,

    [Parameter()]
    [string] $installerArgs
)

function DownloadToFilePath ($downloadUrl, $targetFile)
{
    Write-Output ("Downloading installation files from URL: $downloadUrl to $targetFile")
    $targetFolder = Split-Path $targetFile

    if((Test-Path -path $targetFile))
    {
        Write-Output "Deleting old target file $targetFile"
        Remove-Item $targetFile -Force | Out-Null
    }

    if(-not (Test-Path -path $targetFolder))
    {
        Write-Output "Creating folder $targetFolder"
        New-Item -ItemType Directory -Force -Path $targetFolder | Out-Null
    }

    #Download the file
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
            if ($_.Exception.InnerException){
                Write-Output "InnerException: $($_.InnerException.Message)"
            }
            else {
                Write-Output "Exception: $($_.Exception.Message)"
            }
        }

    } while ($downloadAttempts -lt 5)

    if($downloadAttempts -eq 5)
    {
        Write-Error "Download of $downloadUrl failed repeatedly. Giving up."
    }
}

Write-Output "Installing Visual Studio $version $sku"
$logFolder = Join-path -path $env:ProgramData -childPath "DTLArt_VS"

if($version -eq '2015' )
{
    $vsLog = Join-Path $logFolder "VSInstall.log"
    $argumentList = "$installerArgs /Quiet /NoRestart /Log $vsLog"

    if($sku -eq 'Professional') {
        $downloadUrl = 'http://go.microsoft.com/fwlink/?LinkId=615435'
    }
    elseif($sku -eq 'Enterprise') {
        $downloadUrl = 'http://go.microsoft.com/fwlink/?LinkId=615437'
    }
}
elseif ($version -eq '2017')
{
    if($sku -eq 'Professional') {
        $argumentList = "--quiet --norestart --wait --add Microsoft.VisualStudio.Workload.Azure --add Microsoft.VisualStudio.Workload.Data --add Microsoft.VisualStudio.Workload.ManagedDesktop --add Microsoft.VisualStudio.Workload.NativeDesktop --add Microsoft.VisualStudio.Workload.NetCoreTools --add Microsoft.VisualStudio.Workload.NetWeb --includeRecommended"
        $downloadUrl = 'https://download.visualstudio.microsoft.com/download/pr/100196700/14dd70405e8244481b35017b9a562edd/vs_Professional.exe'
    }
    elseif($sku -eq 'Enterprise') {
        $argumentList = "--quiet --norestart --wait --add Microsoft.VisualStudio.Workload.Azure --add Microsoft.VisualStudio.Workload.Data --add Microsoft.VisualStudio.Workload.ManagedDesktop --add Microsoft.VisualStudio.Workload.NativeDesktop --add Microsoft.VisualStudio.Workload.NativeCrossPlat --add Microsoft.VisualStudio.Workload.NetCoreTools --add Microsoft.VisualStudio.Workload.NetWeb --add Component.GitHub.VisualStudio --add Microsoft.VisualStudio.Component.TestTools.MicrosoftTestManager --add Microsoft.VisualStudio.Component.TestTools.WebLoadTest --includeRecommended"
        $downloadUrl = 'https://download.microsoft.com/download/F/3/4/F3478590-7B38-48B1-BB6E-3141A9A155E7/vs_Enterprise.exe'
    }
}
else
{
    Write-Error "Version is not recognized - allowed values are 2015 and 2017. Specified value: $version"
}

$localFile = Join-Path $logFolder 'vsinstaller.exe'
DownloadToFilePath $downloadUrl $localFile

if(![String]::IsNullOrWhiteSpace($installerArgs))
{
    Write-Output "InstallerArgs value: $installerArgs"
    $argumentList = "$installerArgs $argumentList"
}

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

    Write-Error "Product installation of $localFile failed with exit code: $($retCode.ExitCode.ToString())"    
}
else
{
    Write-Output "Visual Studio install succeeded. Rebooting..."
}
