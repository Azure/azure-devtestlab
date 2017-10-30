Param(
    [Parameter(Mandatory=$true)]
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
        Remove-Item $targetFile | Out-Null
    }

    if((Test-Path -path $targetFolder) -eq $false)
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
        catch [Exception]
        {
            Write-Output "Caught exception during download..."
            if ($_.Exception.InnerException){
                $exceptionMessage = $_.InnerException.Message
                Write-Output "InnerException: $exceptionMessage"
            }
            else {
                $exceptionMessage = $_.Message
                Write-Output "Exception: $exceptionMessage"
            }
        }

    } while ($downloadAttempts -lt 5)

    if($downloadAttempts -eq 5)
    {
        Write-Error "Download of $downloadUrl failed repeatedly. Giving up."
    }
}

if($sku -eq 'Professional') {
    $downloadUrl = 'https://download.visualstudio.microsoft.com/download/pr/100196700/14dd70405e8244481b35017b9a562edd/vs_Professional.exe'
    $downloadFile = "vs_professional.exe"
}
elseif($sku -eq 'Enterprise') {
    $downloadUrl = 'https://download.microsoft.com/download/F/3/4/F3478590-7B38-48B1-BB6E-3141A9A155E7/vs_Enterprise.exe'
    $downloadFile = "vs_enterprise.exe"
}
else {
    Write-Error "SKU is not recognized - allowed values are Professional and Enterprise. Specified value: $sku"
}

$path = Join-path -path $env:ProgramData -childPath "DTLArt_VS"

$localFile = Join-Path $path $downloadFile
DownloadToFilePath $downloadUrl $localFile

Write-Output "Downloaded files: $localFile"

Write-Output "InstallerArgs value: $installerArgs"
$argumentList = "--quiet --norestart --wait --add Microsoft.VisualStudio.Workload.Azure --add Microsoft.VisualStudio.Workload.Data --add Microsoft.VisualStudio.Workload.ManagedDesktop --add Microsoft.VisualStudio.Workload.NativeDesktop --add Microsoft.VisualStudio.Workload.NativeCrossPlat --add Microsoft.VisualStudio.Workload.NetCoreTools --add Microsoft.VisualStudio.Workload.NetWeb --add Component.GitHub.VisualStudio --add Microsoft.VisualStudio.Component.TestTools.MicrosoftTestManager --add Microsoft.VisualStudio.Component.TestTools.WebLoadTest --includeRecommended"
if(![String]::IsNullOrWhiteSpace($installerArgs))
{
    $argumentList = "$installerArgs $argumentList"
}

Write-Output "Running install with the following arguments: $argumentList"

#Run the initial installer and wait for completion.
$retCode = Start-Process -FilePath $localFile -ArgumentList $argumentList -Wait -PassThru

if ($retCode.ExitCode -ne 0 -and $retCode.ExitCode -ne 3010)
{
    $targetLogs = 'c:\VS2017Logs'
    New-Item -ItemType Directory -Force -Path $targetLogs | Out-Null
    Write-Output ('Temp location is ' + $env:TEMP)
    Copy-Item -path $env:TEMP\dd* -Destination $targetLogs
	Write-Error ("Product installation of $downloadFile failed: " + $retCode.ExitCode.ToString())    
}
else
{
    Write-Output "Visual Studio install succeeded"
}
