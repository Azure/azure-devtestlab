$url = 'https://download.microsoft.com/download/4/1/A/41A369FA-AA36-4EE9-845B-20BCC1691FC5/PackageManagement_x64.msi'
$vscodeSetup = "${env:Temp}\PackageManagement_x64.msi"

try
{
    Invoke-WebRequest -Uri $url -OutFile $vscodeSetup
}
catch
{
    Write-Error "Failed to download PowerShell PackageManagement Setup : $_.Message"
}

try
{
    & "${env:Temp}\PackageManagement_x64.msi" "/quiet"
    $exitCode = $LASTEXITCODE
    Write-Host "Installation exited with exit code : $exitCode"

    # Sleep for sometime, because of a possible bug in the msi, where the next command fails if we dont sleep here
    Sleep 10

    Write-Host "Configuring nuget"
    Get-PackageProvider -Name NuGet -ForceBootstrap
    $exitCode = $LASTEXITCODE
    Write-Host "Nuget configuration exited with exit code : $exitCode"

    exit $exitCode
}
catch
{
    Write-Error "Failed to install PowerShell PackageManagement : $_.Message"
    exit -1
}
