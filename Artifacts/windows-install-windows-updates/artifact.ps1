###################################################################################################

#
# PowerShell configurations
#

# NOTE: Because the $ErrorActionPreference is "Stop", this script will stop on first failure.
#       This is necessary to ensure we capture errors inside the try-catch-finally block.
$ErrorActionPreference = "Stop"

# Ensure we set the working directory to that of the script.
Push-Location $PSScriptRoot

###################################################################################################

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
function Download-File ($downloadUrl, $targetFile)
{
    Write-Output ("Downloading installation files from URL: $downloadUrl to $targetFile")
    $targetFolder = Split-Path $targetFile

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
            [Net.ServicePointManager]::SecurityProtocol = "Tls12, Tls11, Tls, Ssl3"
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

###################################################################################################

#
# Main execution block.
#

try
{
    Add-Type -AssemblyName System.IO.Compression.FileSystem

    $scriptFolder = Split-Path $Script:MyInvocation.MyCommand.Path
    $localZipFile = Join-Path $scriptFolder 'PSWindowsUpdate.zip'
    
    # PSWindowsUpdate module downloaded from here:  https://gallery.technet.microsoft.com/scriptcenter/2d191bcd-3308-4edd-9de2-88dff796b0bc
    Download-File "https://gallery.technet.microsoft.com/scriptcenter/2d191bcd-3308-4edd-9de2-88dff796b0bc/file/41459/47/PSWindowsUpdate.zip" $localZipFile
    [System.IO.Compression.ZipFile]::ExtractToDirectory($localZipFile, $scriptFolder)
    
    $modulePath = Join-Path $scriptFolder "PSWindowsUpdate\PSWindowsUpdate.psm1"
    Import-Module $modulePath
    
    Write-Output 'Installing Windows Updates.'
    Get-WUInstall -IgnoreReboot -AcceptAll
    
    Write-Output "Windows Update finished. Rebooting..."

    Write-Host "`nThe artifact was applied successfully.`n"

    # Forcing the restart in script, as the artifact’s postDeployActions may timeout prematurely, prior to the Windows Updates completing, causing undesirable side effects.
    Restart-Computer -Force
}
finally
{
    Pop-Location
}
