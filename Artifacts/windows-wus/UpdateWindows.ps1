
$ErrorActionPreference = "Stop"

function DownloadFile([string] $fileUri, [string] $destination)
{
    $path = ExpandPath $path
    $destination = ExpandPath $destination
    $folderName = Split-Path -Path $destination

    if (-Not (Test-Path -Path $folderName))
    {
        New-Item $folderName -ItemType directory
    }

    Invoke-WebRequest -Uri $fileUri -OutFile $destination
}

function UnzipFile([string] $path, [string] $destination)
{
    $path = ExpandPath $path
    $destination = ExpandPath $destination

    Write-Verbose "Unzipping path $path to $destination"

    if (-Not (Test-Path -Path $destination))
    {
        New-Item $destination -ItemType directory
    }

    $zipPackage = (new-object -com shell.application).NameSpace($path)
    $destinationFolder = (new-object -com shell.application).NameSpace($destination)
    $destinationFolder.CopyHere($zipPackage.Items(), 0x14)
}

function ExpandPath([string] $path)
{
    [System.Environment]::ExpandEnvironmentVariables($path)
}

try
{
    $uri = "https://vsisos.blob.core.windows.net/wus/PSWindowsUpdate.zip"
    $filePath = "%temp%\PSWindowsUpdate.zip"
    $moduleDirectories = @("%USERPROFILE%\Documents\WindowsPowerShell\Modules", "%WINDIR%\System32\WindowsPowerShell\v1.0\Modules")

    DownloadFile $uri $filePath

    foreach ($modulePath in $moduleDirectories)
    {
        UnzipFile -path $filePath -destination $modulePath
    }

    Import-Module PSWindowsUpdate
    Get-WUInstall -NotCategory "Language packs" -AcceptAll -IgnoreReboot
}
catch
{
    if (($null -ne $Error[0]) -and ($null -ne $Error[0].Exception) -and ($null -ne $Error[0].Exception.Message))
    {
        $errMsg = $Error[0].Exception.Message
        Write-Host $errMsg
    }

    # Important note: Throwing a terminating error (using $ErrorActionPreference = "stop") still returns exit 
    # code zero from the powershell script. The workaround is to use try/catch blocks and return a non-zero 
    # exit code from the catch block. 
    exit -1
}
