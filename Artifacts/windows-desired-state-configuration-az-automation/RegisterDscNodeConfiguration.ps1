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
.\DscMetaConfigs.ps1

try {
    # Create the metaconfigurations
$Params = @{
    RegistrationUrl = "$($RegistrationUrl)";
    RegistrationKey = "$($RegistrationKey)";
    ComputerName = @($Machine);
    NodeConfigurationName = "$($ConfigName)";
    RefreshFrequencyMins = $RefreshMinutes;
    ConfigurationModeFrequencyMins = $ConfigMinutes;
    RebootNodeIfNeeded = $Reboot;
    AllowModuleOverwrite = $AllowOverwrite;
    ConfigurationMode = $ConfigMode;
    ActionAfterReboot = $AfterReboot;
    ReportOnly = $False;  # Set to $True to have machines only report to AA DSC but not pull from it
}

# Use PowerShell splatting to pass parameters to the DSC configuration being invoked
# For more info about splatting, run: Get-Help -Name about_Splatting
DscMetaConfigs @Params
}
catch {
    Write-Error $Error[0].Exception
    Write-Error $Error[0].PSMessageDetails
    Stop-Transcript
    exit -1
}
Write-Output "Ending DSC configuration."
Stop-Transcript