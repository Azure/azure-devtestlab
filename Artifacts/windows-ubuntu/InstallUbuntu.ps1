[CmdletBinding()]
param
(
    [Parameter(Mandatory = $true)]
    [string] $distro
)

Write-Output "Creating Ubuntu Distro Folder"
    $sysDrive = $env:SystemRoot.Substring(0,3)
    $ubuntuPath=New-Item -ItemType Directory -Force -Path $sysDrive\Distros\
    Set-Location $ubuntuPath

Write-Output "Downloading Ubuntu Distro"    
    Invoke-WebRequest -Uri https://aka.ms/wsl-ubuntu-$distro -OutFile Ubuntu.appx -UseBasicParsing

Write-Output "Renaming .appx to .zip"    
    Rename-Item $ubuntuPath/Ubuntu.appx $ubuntuPath/Ubuntu.zip

Write-Output "Unzipping Distro"    
    Expand-Archive $ubuntuPath/Ubuntu.zip $ubuntuPath/Ubuntu

Write-Output "Installing Ubuntu"      
    $installerPath=Get-ChildItem -Path $ubuntuPath/Ubuntu -include ubuntu* | where {$_.Extension -eq ".exe"}
    "$installerPath install --root" | cmd