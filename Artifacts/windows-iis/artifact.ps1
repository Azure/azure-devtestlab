$artifactLogFolder = Join-path -path $env:ProgramData -childPath 'DTLArt_IIS'
New-Item -ItemType Directory -Force -Path $artifactLogFolder

$winVerString = (Get-WmiObject Win32_OperatingSystem).Caption
Write-Output "Detected Windows Version: $winVerString"
$scriptFolder = Split-Path $Script:MyInvocation.MyCommand.Path

if ($winVerString -like 'Microsoft Windows Server 2008 R2*' -or $winVerString -like 'Microsoft Windows Server 2012*'){
    Write-Output 'Installing IIS on Windows Server 2008 R2 or 2012'
    $localLog = Join-Path $artifactLogFolder 'IISArtifact.log'
    $pkgMgrExe = join-path $env:windir system32\pkgmgr.exe
    $packages = 'IIS-WebServerRole;IIS-WebServer;IIS-IIS6ManagementCompatibility;IIS-Metabase;IIS-WMICompatibility;IIS-LegacyScripts;IIS-LegacySnapIn'
    $pkgMgrArgs = "/l:$localLog /iu:$packages"
    $pkgMgrProcess = Start-Process -FilePath $pkgMgrExe -ArgumentList $pkgMgrArgs -Wait -PassThru

    if($pkgMgrProcess.ExitCode -eq 0){
        Write-Output 'Successfully installed IIS'
    }
    elseif($pkgMgrProcess.ExitCode -eq 3010){
        Write-Output 'IIS install is finished. A reboot is required.'
    }
    else{
        Write-Error ('Failed to import IIS. Exit code is ' + $pkgMgrProcess.ExitCode.ToString())
    }
}
elseif ($winVerString -like 'Microsoft Windows Server 2016*'){
    Write-Output 'Installing IIS on Windows Server 2016'
    Install-WindowsFeature -name Web-Server -IncludeManagementTools
}
elseif ($winVerString -like 'Microsoft Windows 10*' -or $winVerString -like 'Microsoft Windows 8.1*'){
    Write-Output 'Installing IIS on Windows 8.1 or Windows 10'
    Enable-WindowsOptionalFeature -Online -FeatureName IIS-WebServerRole
}
else {
    Write-Error "This script does not support Windows version $winVerString"
}

