Param(
    # comma or semicolon separated list of chocolatey packages.
    [ValidateNotNullOrEmpty()]
    [Parameter(Mandatory=$True)]
    [string] $packageList,

    [Parameter(Mandatory=$True)]
    [string] $username,

    [Parameter(Mandatory=$True)]
    [string] $password
)

# Ensure Powershell 3 or more is installed.
if ($PSVersionTable.PSVersion.Major -lt 3)
{
    Write-Error "Prior to running this artifact, ensure you have Powershell 3 or higher installed."
    [System.Environment]::Exit(1)
}

$secPassword = ConvertTo-SecureString $password -AsPlainText -Force
$credential = New-Object System.Management.Automation.PSCredential("$env:COMPUTERNAME\$($username)", $secPassword)

$command = $file = $PSScriptRoot + "\ChocolateyPackageInstaller.ps1"

Enable-PSRemoting -Force -SkipNetworkProfileCheck

# Ensure that current process can run scripts. 
Set-ExecutionPolicy -ExecutionPolicy Bypass -Scope Process -Force 

# Work around a bug in the Squirrel installer
Invoke-Command -Credential $credential -ComputerName $env:COMPUTERNAME -ScriptBlock 
{
    Set-ExecutionPolicy -ExecutionPolicy Bypass -Scope Process -Force
    New-Item -Path "HKCU:\Software\Classes\Local Settings\Software\Microsoft\Windows\CurrentVersion\TrayNotify"  -Type directory -Force -ErrorAction Continue
}

Invoke-Command -FilePath $command -Credential $credential -ComputerName $env:COMPUTERNAME -ArgumentList $packageList