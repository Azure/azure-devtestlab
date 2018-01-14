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
Start-Transcript "C:\Artifacts\dsc.log"
Write-Output "Starting DSC configuration for machine: $($env:COMPUTERNAME)"


try {
    & .\DscMetaConfigs.ps1
    Set-DscLocalConfigurationManager -Path ./DscMetaConfigs
}
catch {
    Write-Error $Error[0].Exception
    Write-Error $Error[0].PSMessageDetails
    Stop-Transcript
    exit -1
}
Write-Output "Ending DSC configuration."
Stop-Transcript