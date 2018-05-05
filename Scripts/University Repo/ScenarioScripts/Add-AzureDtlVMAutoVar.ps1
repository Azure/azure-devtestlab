<#
.SYNOPSIS 
    This script adds the number of Azure virtual machines in the DevTest Lab by reading some parameters from AutomationVariable.

.DESCRIPTION
    It allows the creation of the VMs inside a specific lab. This script can be run either from command line or Azure Automation for the creation of the VMs of each lab. 
    Since this script uses some additional configuration parameters which don’t change for each scenario, you can avoid setting them. 
    Such parameters are set as “variables” in the Azure Automation account and they are loaded into the script when it is run as runbook. 

.PARAMETER LabName
    Mandatory. Name of Lab.

.PARAMETER VMCount
    Mandatory. Number of VMs to create with this execution.

.PARAMETER ImageName
    Mandatory. Name of base image in lab.

.PARAMETER TotalLabSize
    Mandatory. Desired total number of VMs in the lab. If the lab already contains the TotalLabSize numebr of machines, it won't create more.

.PARAMETER DaysToExpiry
    Optional. How many days before expiring the VMs (-1 never, 0 today, 1 tomorrow, 2 ...) Defaults to tomorrow.
    Default "1".

.PARAMETER ExpirationTime
    Optional. What time to expire the VMs at. Defaults to 3am. In form of 'HH:mm' in TimeZoneID timezone.
    Default "03:00".

.PARAMETER ShutDownTime
    Optional. Shutdown time for the VMs in the lab. In form of 'HH:mm' in TimeZoneID timezone.
    Default $ExpirationTime.

.PARAMETER StartupTime
    Optional. Starting time for the VMS in the lab. In form of 'HH:mm' in TimeZoneID timezone. You need to set EnableStartupTime to $true as well.

.PARAMETER EnableStartupTime
    Optional. Set to $true to enable starting up of machine at startup time.

.EXAMPLE
    Add-AzureDtlVM -LabName University -VMCount 50 -ImageName "UnivImage" -TotalLabSize 200

.EXAMPLE
    Add-AzureDtlVM -LabName University -VMCount 15 -ImageName "UnivImage" -TotalLabSize 15 -ExpirationTime "16:00" -DaysToExpiry 0

.NOTES

#>
[cmdletbinding()]
param 
(
    [Parameter(Mandatory = $true, HelpMessage = "Name of Lab")]
    [string] $LabName,

    [Parameter(Mandatory = $true, HelpMessage = "Number of VMs to create with this execution")]
    [int] $VMCount,

    [Parameter(Mandatory = $true, HelpMessage = "Name of base image in lab")]
    [string] $ImageName,

    [Parameter(Mandatory = $true, HelpMessage = "Desired total number of VMs in the lab")]
    [int] $TotalLabSize,

    [Parameter(Mandatory = $false, HelpMessage = "How many days before expiring the VMs (-1 never, 0 today, 1 tomorrow, 2 .... Defaults to tomorrow.")]
    [int] $DaysToExpiry = 1,

    [Parameter(Mandatory = $false, HelpMessage = "What time to expire the VMs at. Defaults to 3am. In form of 'HH:mm' in TimeZoneID timezone")]
    [string] $ExpirationTime = "03:00",

    [Parameter(Mandatory = $false, HelpMessage = "Shutdown time for the VMs in the lab. In form of 'HH:mm' in TimeZoneID timezone")]
    [string] $ShutDownTime = $ExpirationTime,

    [Parameter(Mandatory = $false, HelpMessage = "What time to start the VMs at. In form of 'HH:mm' in TimeZoneID timezone")]
    [string] $StartupTime = "02:30",

    [Parameter(Mandatory = $false, HelpMessage = "Set to true to enable starting up of machine at startup time.")]
    [boolean] $EnableStartupTime
)

trap {
    # NOTE: This trap will handle all errors. There should be no need to use a catch below in this
    #       script, unless you want to ignore a specific error.
    Handle-LastError
}

. .\Common.ps1

try {
    $credentialsKind = InferCredentials

    if ($credentialsKind -eq "Runbook") {
        $ShutdownPath = Get-AutomationVariable -Name 'ShutdownPath'
        $VNetName = Get-AutomationVariable -Name 'VNetName'
        $SubnetName = Get-AutomationVariable -Name 'SubnetName'
        $Size = Get-AutomationVariable -Name 'Size'
		$StorageType = Get-AutomationVariable -Name 'StorageType'
        $TemplatePath = Get-AutomationVariable -Name 'TemplatePath'
    }
    else {
        throw "This script just works under Azure Automation, and expects the variables in the code just above"
    }

    . .\Add-AzureDtlVM.ps1 -LabName $LabName -VMCount $VMCount -ImageName $ImageName -ShutDownTime $ShutDownTime -TotalLabSize $TotalLabSize `
        -ShutdownPath $ShutdownPath -TemplatePath $TemplatePath -VNetName $VNetName -SubnetName $SubnetName -Size $Size -StorageType $StorageType -ExpirationTime $ExpirationTime -DaysToExpiry $DaysToExpiry `
        -StartupTime $StartupTime -EnableStartupTime $EnableStartupTime


} finally {
    if ($credentialsKind -eq "File") {
        1..3 | % { [console]::beep(2500, 300) } # Make a sound to indicate we're done if running from command line.
    }
    popd    
}
