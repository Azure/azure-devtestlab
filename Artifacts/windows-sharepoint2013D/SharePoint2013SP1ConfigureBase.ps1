Param(
    [ValidateNotNullOrEmpty()]
    [Parameter(Mandatory=$True)]
    [string] $user
)

Add-PsSnapin Microsoft.SharePoint.PowerShell

$logFile = "InstallShpt2013SP1.log"
$psconfig = 'Microsoft Shared\Web Server Extensions\15\bin\psconfig.exe'
$path = Join-path -path $env:ProgramData -childPath "DTLArt_Shpt2013"

$localconfig = Join-Path $env:CommonProgramFiles $psconfig
$localLog = Join-Path $path $logFile
Add-content $localLog -Value "$(Get-Date)"
Add-content $localLog -value "Starting Congfiguration"

Start-Service wsservice

$argumentList = " -cmd setup"

$retCode = Start-Process -FilePath $localconfig -ArgumentList $argumentList -Wait -PassThru

if ($retCode.ExitCode -ne 0)
{
    Add-content $localLog -value "SharePoint 2013 Configuration non-zero error code"
    Add-content $localLog -value $retCode.ExitCode.ToString()
}
else
{
    Add-content $localLog -value "SharePoint 2013 Setup succeeded"
}

$retCode = Add-SPShellAdmin -UserName $user

Add-content $localLog -Value "Add Shell Admin code: $($retCode)"

$template = Get-SPWebTemplate "DEV#0"
$retCode = New-SPSite -Url "http://$env:COMPUTERNAME" -OwnerAlias $user -Template $template

Add-content $localLog -Value "New SP Site: $retCode"

Add-content $localLog -Value "$(Get-Date)"
Add-content $localLog -value "Completed the site creation"

