Param(
    # comma or semicolon separated list of chocolatey packages.
    [ValidateNotNullOrEmpty()]
    [Parameter(Mandatory=$True)]
    [string] $RawPackagesList,

    [Parameter(Mandatory=$True)]
    [string] $Username,

    [Parameter(Mandatory=$True)]
    [string] $Password
)

$secPassword = ConvertTo-SecureString $Password -AsPlainText -Force
$credential = New-Object System.Management.Automation.PSCredential("$env:COMPUTERNAME\$($Username)", $secPassword)

$command = $file = $PSScriptRoot + "\ChocolateyPackageInstaller.ps1"

Enable-PSRemoting –force
Invoke-Command -FilePath $command -Credential $credential -ComputerName $env:COMPUTERNAME -ArgumentList $RawPackagesList
Disable-PSRemoting -Force