[CmdletBinding()]
param (
    [string]
    $Machine = $env:COMPUTERNAME,   
    [string]
    $AutomationAccount,
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
    $AllowOverwrite
)
Start-Transcript "C:\Artifacts\dsc.log"
Write-Output "Starting DSC configuration for account: $($AutomationAccount), machine: $($env:COMPUTERNAME)"

try {
    $vm = Find-AzureRmResource -ResourceNameContains $Machine -ResourceType "Microsoft.Compute/virtualMachines" -Verbose
    $automation = Find-AzureRmResource -ResourceNameEquals $AutomationAccount -ResourceType "Microsoft.Automation/automationAccounts" -Verbose

    Register-AzureRmAutomationDscNode $automation -AzureVMName $vm.Name -NodeConfigurationName $ConfigName `
        -ConfigurationMode $ConfigMode -ConfigurationModeFrequencyMins $ConfigMinutes `
        -RefreshFrequencyMins $RefresMinutes -RebootNodeIfNeeded $Reboot -ActionAfterReboot $AfterReboot `
        -AllowModuleOverwrite $AllowOverwrite -AzureVMResourceGroup $vm.ResourceGroupName `
        -AzureVMLocation $vm.Location -AutomationAccountName $automation.Name `
        -ResourceGroupName $automation.ResourceGroupName -Verbose
}
catch {
    Write-Error $Error[0].Exception
    Write-Error $Error[0].PSMessageDetails
    Stop-Transcript
    exit -1
}
Write-Output "Ending DSC configuration."
Stop-Transcript