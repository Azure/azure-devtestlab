# The DSC configuration that will generate metaconfigurations
# Courtesy of https://docs.microsoft.com/en-us/azure/automation/automation-dsc-onboarding#secure-registration
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

