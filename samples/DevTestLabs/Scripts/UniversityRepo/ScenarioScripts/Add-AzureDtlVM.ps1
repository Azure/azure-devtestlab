<#
.SYNOPSIS 
    This script adds the specified number of Azure virtual machines to a DevTest Lab.

.DESCRIPTION
    It allows the creation of the VMs inside a specific lab. This script can be run either from command line or Azure Automation for the creation of the VMs of each lab. 

.PARAMETER LabName
    Mandatory. Name of Lab.

.PARAMETER VMCount
    Mandatory. Number of VMs to create with this execution.

.PARAMETER ImageName
    Mandatory. Name of base image in lab.

.PARAMETER TotalLabSize
    Mandatory. Desired total number of VMs in the lab. If the lab already contains the TotalLabSize numebr of machines, it won't create more.

.PARAMETER BatchSize
    Optional. How many VMs to create in each batch.
    Default 30.

.PARAMETER TemplatePath
    Optional. Path to the Deployment Template File or URL of the template file when running from Azure Automation.
    Default ".\dtl_multivm_customimage.json".

.PARAMETER ShutdownPath
    Optional. Path to the Shutdown file or URL of the shutdown file when running from Azure Automation.
    Default ".\dtl_shutdown.json".

.PARAMETER Size
    Optional. Size of VM image.
    Default "Standard_A2_v2".

.PARAMETER StorageType
	Optional. Type of storage
	Default "Standard".

.PARAMETER VMNameBase
    Optional. Prefix for new VMs.
    Default "vm".

.PARAMETER VNetName
    Optional. Virtual Network Name.
    Default "dtl" + $LabName.

.PARAMETER SubnetName
    Optional. Subnet Name.
    Default "dtl" + $LabName + "SubNet".

.PARAMETER location
    Optional. Location for the Machines.
    Default "westeurope".

.PARAMETER TimeZoneId
    Optional. TimeZone for machines.
    Default "Central European Standard Time".

.PARAMETER profilePath
    Optional. Path to file with Azure Profile. How to generate this file is explained at the end of the Readme for the repo (https://github.com/lucabol/University).
    Default "$env:APPDATA\AzProfile.txt".

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

.EXAMPLE
    Add-AzureDtlVM -LabName University -VMCount 15 -ImageName "UnivImage" -TotalLabSize 15 -ExpirationTime "16:00" -DaysToExpiry 0 -location "centralus" -TimeZoneId "Central Standard Time"

.EXAMPLE
    Add-AzureDtlVM -LabName University -VMCount 15 -ImageName "UnivImage" -TotalLabSize 15 -TemplatePath "https://vlabresources.blob.core.windows.net/content/dtl_multivm_customimage.json" -ShutdownPath "https://vlabresources.blob.core.windows.net/content/dtl_shutdown.json"

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

    [Parameter(Mandatory = $false, HelpMessage = "How many VMs to create in each batch")]
    [int] $BatchSize = 30,

    [Parameter(Mandatory = $false, HelpMessage = "Path to the Deployment Template File")]
    [string] $TemplatePath = ".\dtl_multivm_customimage.json",

    [Parameter(Mandatory = $false, HelpMessage = "Path to the Shutdown file")]
    [string] $ShutdownPath = ".\dtl_shutdown.json",

    [Parameter(Mandatory = $false, HelpMessage = "Size of VM image")]
    [string] $Size = "Standard_A2_v2",
	
	[Parameter(Mandatory = $false, HelpMessage = "Type of storage")]
	[string] $StorageType = "Standard",

    [Parameter(Mandatory = $false, HelpMessage = "Prefix for new VMs")]
    [string] $VMNameBase = "vm",

    [Parameter(Mandatory = $false, HelpMessage = "Virtual Network Name")]
    [string] $VNetName = "dtl" + $LabName,

    [Parameter(Mandatory = $false, HelpMessage = "SubNetName")]
    [string] $SubnetName = "dtl" + $LabName + "SubNet",

    [Parameter(Mandatory = $false, HelpMessage = "Location for the Machines")]
    [string] $location = "westeurope",

    [Parameter(Mandatory = $false, HelpMessage = "TimeZone for machines")]
    [string] $TimeZoneId = "Central European Standard Time",

    [Parameter(Mandatory = $false, HelpMessage = "Path to file with Azure Profile")]
    [string] $profilePath = "$env:APPDATA\AzProfile.txt",

    [Parameter(Mandatory = $false, HelpMessage = "How many days before expiring the VMs (-1 never, 0 today, 1 tomorrow, 2 .... Defaults to tomorrow.")]
    [int] $DaysToExpiry = 1,

    [Parameter(Mandatory = $false, HelpMessage = "What time to expire the VMs at. Defaults to 3am. In form of 'HH:mm' in TimeZoneID timezone")]
    [string] $ExpirationTime = "03:00",

    [Parameter(Mandatory = $false, HelpMessage = "What time to start the VMs at. In form of 'HH:mm' in TimeZoneID timezone")]
    [string] $StartupTime = "02:30",

    [Parameter(Mandatory = $false, HelpMessage = "Set to true to enable starting up of machine at startup time.")]
    [boolean] $EnableStartupTime,
   
    [Parameter(Mandatory = $false, HelpMessage = "Shutdown time for the VMs in the lab. In form of 'HH:mm' in TimeZoneID timezone")]
    [string] $ShutDownTime = $ExpirationTime       
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
        $file = Invoke-WebRequest -Uri $TemplatePath -UseBasicParsing
        $templateContent = $file.Content
    }
    else {
        $path = Resolve-Path $TemplatePath
        $templateContent = [IO.File]::ReadAllText($path)
    }

    if ($BatchSize -gt 100) {
        throw "BatchSize must be less or equal to 100"
    }
    
    # default batch size for removing failed VMs
    $removeBatchSize = 2

    LogOutput "Start provisioning ..."

    LoadAzureCredentials -credentialsKind $credentialsKind -profilePath $profilePath
    
    # Create deployment names
    $depTime = (Get-Date).ToUniversalTime().ToString("yyyyMMddHHmmss")
    LogOutput "StartTime: $depTime"
    $deploymentName = "Deployment_$LabName_$depTime"
    $shutDeployment = $deploymentName + "Shutdown"
    LogOutput "Deployment Name: $deploymentName"
    LogOutput "Shutdown Deployment Name: $shutDeployment"
    LogOutput "Shutdown time: $ShutDownTime"

    $azVer = GetAzureModuleVersion
    if ($azVer -ge "3.8.0") {
        $SubscriptionID = (Get-AzureRmContext).Subscription.Id
    }
    else {
        $SubscriptionID = (Get-AzureRmContext).Subscription.SubscriptionId
    }
    
    LogOutput "Subscription id: $SubscriptionID"
    $ResourceGroupName = GetResourceGroupName -labname $LabName
    LogOutput "Resource Group: $ResourceGroupName"

    # Set the expiration date. This needs to be passed to DevTestLab in UTC time, so it is converted to UTC from TimeZoneId time
    if ($DaysToExpiry -lt 0) {
        $DaysToExpiry = 365 * 100 # Expire in 100 years (aka never) 
    }

    $tz = [timezoneinfo]::FindSystemTimeZoneById($TimeZoneId)
    $ExpiryDateTime = ([timezoneinfo]::ConvertTimeFromUtc([datetime]::UtcNow, $tz))
    $ExpiryDateTime = $ExpiryDateTime.Date.AddDays($DaysToExpiry)
    $Time = [System.Timespan]::Parse($ExpirationTime)
    $ExpiryDateTime = $ExpiryDateTime.Add($Time)
    
    $ExpirationUtc = [system.timezoneinfo]::ConvertTimeToUtc($ExpiryDateTime, $tz)
    if ($ExpirationUtc -le [DateTime]::UtcNow) {
        throw "Expiration date $ShutDownDate (or in UTC $ExpirationUtc) must be in the future."
    }
    $ExpirationDate = $ExpirationUtc.ToString("yyyy-MM-ddTHH:mm:ss")
    LogOutput "Expiration Date: $ExpirationDate"

    $ShutDownTimeHours = ([DateTime]$ShutDownTime).ToString("HHmm")
    LogOutput "Shutdown Time hours: $ShutdownTimeHours"

    $StartupTimeHours = ([DateTime]$StartupTime).ToString("HHmm")
    LogOutput "Startup Time hours: $StartupTimeHours"

    LogOutput "Start deployment of Shutdown time ..."
    $shutParams = @{
        newLabName   = $LabName
        shutDownTime = $ShutDownTimeHours
        startupTime = $StartupTimeHours
        timeZoneId   = $TimeZoneId
    }
    New-AzureRmResourceGroupDeployment -Name $shutDeployment -ResourceGroupName $ResourceGroupName -TemplateFile $ShutdownPath -TemplateParameterObject $shutParams | Write-Verbose
    LogOutput "Shutdown time deployed."

    # Check that the Lab is not already full
    [array] $vms = GetAllLabVMsExpanded -LabName $LabName
    [array] $failed = $vms | ? { $_.Properties.provisioningState -eq 'Failed' }
    $MissingVMs = $TotalLabSize - $vms.count + $failedVms.count

    # The script tries to create the minimum of what it was asked for and the missing VMs
    $VMCount = [math]::min($VMCount, $MissingVMs)
    # There could be few missing VMs, hence the size of batch can become more than VMs to create
    $BatchSize = [math]::min($BatchSize, $VMCount)

    LogOutput "Lab $LabName, Total VMS:$($vms.count), Failed:$($failedVms.count), Missing: $MissingVMs, ToCreate: $VMCount, Batches of: $BatchSize"

    if ($VMCount -gt 0) {
        LogOutput "Start creating VMs ..."
        $labId = "/subscriptions/$SubscriptionId/resourcegroups/$ResourceGroupName/providers/Microsoft.DevTestLab/labs/$LabName"
        LogOutput "LabId: $labId"
    
        # Create unique name base for this deployment by taking the current time in seconds from a startDate, for the sake of using less characters
        # as the max number of characters in an Azure vm name is 16. This algo should produce vmXXXXXXXX (10 chars) leaving 6 chars free for the VM number
        $baseDate = get-date -date "01-01-2016"
        $ticksFromBase = (get-date).ticks - $baseDate.Ticks
        $secondsFromBase = [math]::Floor($ticksFromBase / 10000000)
        $VMNameBase = $VMNameBase + $secondsFromBase.ToString()
        LogOutput "Base Name $VMNameBase"

        $tokens = @{
            Count              = $BatchSize
            ExpirationDate     = $ExpirationDate
            ImageName          = "/subscriptions/$SubscriptionID/ResourceGroups/$ResourceGroupName/providers/Microsoft.DevTestLab/labs/$LabName/customImages/$ImageName"
            LabName            = $LabName
            Location           = $location
            Name               = $VMNameBase
            ResourceGroupName  = $ResourceGroupName
            ShutDownTime       = $ShutDownTimeHours
            Size               = $Size
            SubnetName         = $SubnetName
            SubscriptionId     = $SubscriptionId
            TimeZoneId         = $TimeZoneId
            VirtualNetworkName = $VNetName
            EnableStartupTime  = If ($EnableStartupTime) {"true"} Else {"false"}
            StorageType        = $StorageType
        }

        $loops = [math]::Floor($VMCount / $BatchSize)
        $rem = $VMCount - $loops * $BatchSize
        LogOutput "VMCount: $vmcount, Loops: $loops, Rem: $rem"

        # Iterating loops time
        for ($i = 0; $i -lt $loops; $i++) {
            $tokens["Name"] = $VMNameBase + $i.ToString()
            LogOutput "Processing batch: $i"
            Create-VirtualMachines -LabId $labId -Tokens $tokens -content $templateContent
            LogOutput "Finished processing batch: $i"
        }

        # Process reminder
        if ($rem -ne 0) {
            LogOutput "Processing reminder"
            $tokens["Name"] = $VMNameBase + "Rm"
            $tokens["Count"] = $rem
            Create-VirtualMachines -LabId $labId -Tokens $tokens -content $templateContent
            LogOutput "Finished processing reminder"
        }
    }

    # Check if there are Failed VMs in the lab and deletes them, using the same batchsize as creation.
    # It is done even if the failed VMs haven't been created by this script, just for the sake of cleaning up the lab.
    LogOutput "Check for failed VMs"
    [array] $vms = GetAllLabVMsExpanded -LabName $LabName
    [array] $failed = $vms | ? { $_.Properties.provisioningState -eq 'Failed' }
    LogOutput "Detected $($failed.Count) failed VMs"

    RemoveBatchVms -vms $failed -batchSize $removeBatchSize -credentialsKind $credentialsKind -profilePath $profilePath
    LogOutput "Deleted $($failed.Count) failed VMs"

    LogOutput "All done!"

} finally {
    if ($credentialsKind -eq "File") {
        1..3 | % { [console]::beep(2500, 300) } # Make a sound to indicate we're done if running from command line.
    }
    popd
}
