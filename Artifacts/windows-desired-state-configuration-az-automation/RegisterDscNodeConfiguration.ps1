[CmdletBinding()]
param (
    [string]
    $Machine = $env:COMPUTERNAME,   
    [string]
    $ConfigName,
    $ConfigMode,
    [Int32]
    $ConfigMinutes,
    [Int32]
    $RefreshMinutes,
    [Boolean]
    $Reboot,
    $AfterReboot,
    [Boolean]
    $AllowOverwrite,
    [string]
    $RegistrationUrl,
    [string]
    $RegistrationKey
)

function Finish-Transcript ($logFilePath){
    Stop-Transcript
    Get-Content -Path $logFilePath | Write-Output
}

$logfile = "C:\Artifacts\dsc.log"

Start-Transcript $logfile
Write-Output "Starting DSC configuration for machine: $($env:COMPUTERNAME)"


try {
    & .\DscMetaConfigs.ps1
    Set-DscLocalConfigurationManager -Path ./DscMetaConfigs -Verbose
}
catch {
    Write-Error $Error[0].Exception
    Write-Error $Error[0].PSMessageDetails
    Finish-Transcript $logfile
    exit -1
}
Write-Output "Ending DSC configuration."
Finish-Transcript $logfile
