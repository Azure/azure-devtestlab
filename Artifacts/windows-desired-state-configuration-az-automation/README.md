## PowerShell Desired State Configuration Registrar - Azure Automation
This artifact will register a DevTest Labs virtual machine with a Desired State configuration Pull server.
This example follows the [Secure Registration](https://docs.microsoft.com/en-us/azure/automation/automation-dsc-onboarding#secure-registration) example for Azure Automation DSC.
### Inputs
- `registrationUrl`: The URL of the DSC pull server.  Required.
- `registrationKey`: The registration key associated with the pull server.  Required.
- `configurationName`: The name of the DSC configuration to be applied.  Required.
- `configurationMode`: How DSC should apply the changes (ApplyOnly, ApplyAndAutocorrect, ApplyAndMonitor).  Required.
- `configurationFrequency`: The rate at which configurations will be performed.  Default (and minimum) is 15 minutes.  Required.
- `refreshFrequency`: The rate at which refreshes will occur.  Default (and minimum) is 30 minutes.  Required.
- `rebootIfNeeded`: Indicates whether a machine reboot can be performed if needed. 
- `activityAfterReboot`: Action to take if a reboot is required (ContinueConfiguration, StopConfiguration).
- `allowOverwriteModule`: Indicates whether the existing module can be overwritten during configuration.