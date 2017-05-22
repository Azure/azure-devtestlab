Param(
    [ValidateNotNullOrEmpty()]
    [Parameter(Mandatory=$True)]
    [string] $downloadUrl
)

$logFile = "InstallShpt2013SP1.log"
$preInstaller = "prerequisiteinstaller.exe"
$sharePointInstaller = "sharepoint.exe"
$rebootTemp = "rebootTrue.log"

$path = Join-path -path $env:ProgramData -childPath "DTLArt_Shpt2013"

if(!(Test-Path -path $path)){
    New-Item -ItemType Directory -Force -Path $path
}

$localFile = Join-Path $path $sharePointInstaller
$localLog = Join-Path $path $logFile
$localreboot = Join-Path $path $rebootTemp

Add-content $localLog -value "Starting install process"

Invoke-WebRequest -Uri $shptUrl -OutFile $localFile

# Add feature to workaround issue https://support.microsoft.com/en-us/kb/2581903
Add-WindowsFeature NET-Framework
Add-Content $localLog -value "Added Net Framework"

$wClient = New-Object System.Net.WebClient
$wClient.DownloadFile($downloadUrl,$localFile)

Add-content $localLog -value "Downloaded files"

#Extract sharePoint Files from downloaded file

$argumentList = -join (" /quiet /extract:" + $path)

$retCode = Start-Process -FilePath $localFile -ArgumentList $argumentList -Wait -PassThru

if ($retCode.ExitCode -ne 0)
{
    Add-content $localLog -value "SharePoint 2013 extract failed"   
    break
}
Add-content $localLog -value "SharePoint 2013 extract succeeded"

#Run prereqinstaller
$localFile = Join-Path $path $preInstaller
$argumentList = " /unattended"

$retCode = Start-Process -FilePath $localFile -ArgumentList $argumentList -Wait -PassThru

if ($retCode.ExitCode -eq 0)
{
    Add-content $localLog -value "SharePoint 2013 prerequisite installer succeeded - no reboot"
}
elseif ($retCode.ExitCode -eq 1001)
{
    Add-content $localLog -value "SharePoint 2013 prerequisite installer succeeded - 1001 block needs reboot"
    Add-content $localreboot -Value "Needs reboot"
}
elseif ($retCode.ExitCode -eq 3010)
{
    Add-content $localLog -value "SharePoint 2013 prerequisite installer succeeded - 3010 reboot"
    Add-content $localreboot -Value "Needs reboot"
}
else
{
    Add-content $localLog -value "SharePoint 2013 prerequisite installer failed"
    Exit -1
}

Restart-Computer -Force

