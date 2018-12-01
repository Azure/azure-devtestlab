[CmdletBinding()]
param
(
    [Parameter(Mandatory = $true)]
    [string] $distro
)
$ErrorActionPreference = 'Stop'
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
try
{
    Write-Host "Creating Ubuntu Distro Folder"
        $sysDrive = $env:SystemRoot.Substring(0,3)
        $ubuntuPath=New-Item -ItemType Directory -Force -Path $sysDrive\Distros\
        Set-Location $ubuntuPath

    Write-Host "Downloading Ubuntu Distro"    
        Invoke-WebRequest -Uri https://aka.ms/wsl-ubuntu-$distro -OutFile Ubuntu.appx -UseBasicParsing

    Write-Host "Renaming .appx to .zip"    
        Rename-Item $ubuntuPath/Ubuntu.appx $ubuntuPath/Ubuntu.zip

    Write-Host "Unzipping Distro"    
        Expand-Archive $ubuntuPath/Ubuntu.zip $ubuntuPath/Ubuntu

    Write-Host "Installing Ubuntu"      
        $installerPath=Get-ChildItem -Path $ubuntuPath/Ubuntu -include ubuntu* | where {$_.Extension -eq ".exe"}
        "$installerPath install --root" | cmd
}
finally
{
    popd
}
