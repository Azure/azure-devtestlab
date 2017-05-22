$logFile = "InstallShpt2013SP1.log"
$preInstaller = "prerequisiteinstaller.exe"
$rebootTemp = "rebootTrue.log"

$path = Join-path -path $env:ProgramData -childPath "DTLArt_Shpt2013"

if(!(Test-Path -path $path)){
    New-Item -ItemType Directory -Force -Path $path
}

$localFile = Join-Path $path $preInstaller
$localLog = Join-Path $path $logFile
$localreboot = Join-Path $path $rebootTemp

If (Test-Path $localreboot){

    Remove-Item -Path $localreboot

    Add-content $localLog -value "Starting PreRequisite /continue process"

    #Extract sharePoint Files from downloaded file

    $argumentList = " /unattended /continue"

    $retCode = Start-Process -FilePath $localFile -ArgumentList $argumentList -Wait -PassThru

    if ($retCode.ExitCode -eq 0)
    {
        Add-content $localLog -value "SharePoint 2013 prerequisite installer 2 succeded - no reboot"
    }
    elseif ($retCode.ExitCode -eq 1001)
    {
        Add-content $localLog -value "SharePoint 2013 prerequisite installer 2 succeded - 1001 blocking needs reboot"
    }
    elseif ($retCode.ExitCode -eq 3010)
    {
        Add-content $localLog -value "SharePoint 2013 prerequisite installer 2 succeded - 3010 reboot"
    }
    else
    {
        Add-content $localLog -value "SharePoint 2013 prerequisite installer 2 failed"
        Add-Content $localLog -value $retCode.ExitCode.ToString()
        Exit -1
    }

}
else
{
    Add-content $localLog -value "PreRequisite /continue process not needed."    
}

Restart-Computer -Force
