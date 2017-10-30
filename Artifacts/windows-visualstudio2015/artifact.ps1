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
    $downloadUrl = 'http://go.microsoft.com/fwlink/?LinkId=615435'
    $downloadFile = "vs_professional.exe"
}
elseif($sku -eq 'Enterprise') {
    $downloadUrl = 'http://go.microsoft.com/fwlink/?LinkId=615437'
    $downloadFile = "vs_enterprise.exe"
}
else {
    Write-Error "SKU is not recognized - allowed values are Professional and Enterprise. Specified value: $sku"
}

#VS Install log file
$vslogFile = "VSInstall.log"

$path = Join-path -path $env:ProgramData -childPath "DTLArt_VS"

$localFile = Join-Path $path $downloadFile
$vsLog = Join-Path $path $vslogFile 
DownloadToFilePath $downloadUrl $localFile

Write-Output "Downloaded files: $localFile"

$argumentList = "$installerArgs /Quiet /NoRestart /Log $vsLog"
Write-Output "Running install with the following arguments: $argumentList"

#Run the install and wait for completion.
$retCode = Start-Process -FilePath $localFile -ArgumentList $argumentList -Wait -PassThru

if ($retCode.ExitCode -ne 0)
{
	Write-Output ("Visual Studio installed with reboot: " + $retCode.ExitCode.ToString())
    Restart-Computer -Force
}
Write-Output "Visual Studio install succeeded"
