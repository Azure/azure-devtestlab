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

$vm = Find-AzureRmResource -ResourceNameContains $Machine -ResourceType "Microsoft.Compute/virtualMachines" 
$automation = Find-AzureRmResource -ResourceName $AutomationAccount

Register-AzureRmAutomationDscNode $automation -AzureVMName $vm.Name -NodeConfigurationName $ConfigName `
-ConfigurationMode $ConfigMode -ConfigurationModeFrequencyMins $ConfigMinutes `
-RefreshFrequencyMins $RefresMinutes -RebootNodeIfNeeded=$Reboot -ActionAfterReboot $AfterReboot `
-AllowModuleOverwrite=$AllowOverwrite -AzureVMResourceGroup $vm.ResourceGroupName `
-AzureVMLocation $vm.Location