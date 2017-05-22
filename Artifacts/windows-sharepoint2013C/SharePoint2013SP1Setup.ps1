Param(
    [string] $pidKey
)

$logFile = "InstallShpt2013SP1.log"
$setup = "setup.exe"
$configXml = "config.xml"
$changeNet = "ChangeNetVersion.ps1"
$revertNet = "RevertNetVersion.ps1"

$path = Join-path -path $env:ProgramData -childPath "DTLArt_Shpt2013"

if(!(Test-Path -path $path)){
    New-Item -ItemType Directory -Force -Path $path
}

$localFile = Join-Path $path $setup
$localConfig = Join-Path $path $configXml 
$localLog = Join-Path $path $logFile
$localNet = Join-Path $PSScriptRoot $changeNet
$localRNet = Join-Path $PSScriptRoot $revertNet

#Set Net version to 4.5
$osVer = [System.Environment]::OSVersion.Version
if ($osVer.Major -ge '6' -and $osVer.Minor -gt '1')
{
    Add-content $localLog -value "Starting NetVersion change"
    Add-content $localLog -Value $localNet
    Enable-PSRemoting –Force -SkipNetworkProfileCheck
    Set-ExecutionPolicy -ExecutionPolicy Bypass -Scope Process -Force 
    Invoke-Expression -Command $localNet
    Add-content $localLog -value "Finished Net Version"
}
else
{
    Add-Content $localLog -value "Older OS, not executing NetVersionChange"
}
#Build Config.xml

Add-content $localConfig -value "<Configuration>"
Add-content $localConfig -value "     <Package Id=`"sts`">"
Add-content $localConfig -value "          <Setting Id=`"SETUPTYPE`" Value=`"CLEAN_INSTALL`" />"
Add-content $localConfig -value "     </Package>"
$tempPID = "     <PIDKEY Value=""" + $pidKey + """/>"
if ($tempPID -ne 0)
{
    Add-content $localConfig -value $tempPID
}
Add-content $localConfig -value "     <Logging Type=`"verbose`" Path=`"$path`" Template=`"SharePoint Foundation Setup(*).log`" />"
Add-content $localConfig -value "     <Setting Id=`"SERVERROLE`" Value=`"SINGLESERVER`" />"
Add-content $localConfig -value "     <Setting Id=`"UsingUIInstallMode`" Value=`"0`" />"
Add-content $localConfig -value "     <Display Level=`"none`" CompletionNotice=`"no`" />"
Add-content $localConfig -value "     <Setting Id=`"SETUP_REBOOT`" Value=`"Never`" />"
Add-content $localConfig -value "</Configuration>"

Add-content $localLog -value "Starting Setup"

#Run setup.exe with /config 

$argumentList = -join (" /config ", $localConfig)

$retCode = Start-Process -FilePath $localFile -ArgumentList $argumentList -Wait -PassThru

if ($retCode.ExitCode -ne 0)
{
    Add-content $localLog -value "SharePoint 2013 Setup non-zero ExitCode"
    Add-content $localLog -value $retCode.ExitCode.ToString()
}
else
{
    Add-content $localLog -value "SharePoint 2013 Setup succeeded"
}

if ($osVer.Major -ge '6' -and $osVer.Minor -gt '1')
{
    Add-content $localLog -value "Starting NetVersion revert"
    Add-content $localLog -Value $localRNet
    Enable-PSRemoting –Force -SkipNetworkProfileCheck
    Set-ExecutionPolicy -ExecutionPolicy Bypass -Scope Process -Force 
    Invoke-Expression -Command $localRNet
    Add-content $localLog -value "Finished Net Revert"
}

Remove-Item $localConfig

Restart-Computer -Force