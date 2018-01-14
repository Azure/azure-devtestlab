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
    [DscLocalConfigurationManager()]
Configuration DscMetaConfigs
{

    param
    (
        [Parameter(Mandatory=$True)]
        [String]$RegistrationUrl,

        [Parameter(Mandatory=$True)]
        [String]$RegistrationKey,

        [Parameter(Mandatory=$True)]
        [String[]]$ComputerName,

        [Int]$RefreshFrequencyMins = 30,

        [Int]$ConfigurationModeFrequencyMins = 15,

        [String]$ConfigurationMode = "ApplyAndMonitor",

        [String]$NodeConfigurationName,

        [Boolean]$RebootNodeIfNeeded= $False,

        [String]$ActionAfterReboot = "ContinueConfiguration",

        [Boolean]$AllowModuleOverwrite = $False,

        [Boolean]$ReportOnly
    )

    if(!$NodeConfigurationName -or $NodeConfigurationName -eq "")
    {
        $ConfigurationNames = $null
    }
    else
    {
        $ConfigurationNames = @($NodeConfigurationName)
    }

    if($ReportOnly)
    {
    $RefreshMode = "PUSH"
    }
    else
    {
    $RefreshMode = "PULL"
    }

    Node $ComputerName
    {

        Settings
        {
            RefreshFrequencyMins = $RefreshFrequencyMins
            RefreshMode = $RefreshMode
            ConfigurationMode = $ConfigurationMode
            AllowModuleOverwrite = $AllowModuleOverwrite
            RebootNodeIfNeeded = $RebootNodeIfNeeded
            ActionAfterReboot = $ActionAfterReboot
            ConfigurationModeFrequencyMins = $ConfigurationModeFrequencyMins
        }

        if(!$ReportOnly)
        {
        ConfigurationRepositoryWeb AzureAutomationDSC
            {
                ServerUrl = $RegistrationUrl
                RegistrationKey = $RegistrationKey
                ConfigurationNames = $ConfigurationNames
            }

            ResourceRepositoryWeb AzureAutomationDSC
            {
            ServerUrl = $RegistrationUrl
            RegistrationKey = $RegistrationKey
            }
        }

        ReportServerWeb AzureAutomationDSC
        {
            ServerUrl = $RegistrationUrl
            RegistrationKey = $RegistrationKey
        }
    }
}
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