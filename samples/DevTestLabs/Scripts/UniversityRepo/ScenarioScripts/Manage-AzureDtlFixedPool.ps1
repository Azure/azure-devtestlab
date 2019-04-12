<#
.SYNOPSIS 
    This script guarantees that the Virtual Machine pool of the Lab equals to the PoolSize specified as Azure Tag of Lab.

.DESCRIPTION
    This script guaratees the presence of an appropriate number of Virtual machines inside the Lab depending on the number you can find inside an Azure Tag, PoolSize.

.PARAMETER LabName
    Mandatory. Name of Lab.

.PARAMETER ImageName
    Mandatory. Name of base image in lab.

.PARAMETER BatchSize
    Optional. How many VMs to create in each batch.
    Default 50.

.PARAMETER TemplatePath
    Optional. Path to the Deployment Template File.
    Default ".\dtl_multivm_customimage.json".

.PARAMETER Size
    Optional. Size of VM image.
    Default "Standard_DS2".

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

.EXAMPLE
    Manage-AzureDtlFixedPool -LabName University -ImageName "UnivImage"

.EXAMPLE
    Manage-AzureDtlFixedPool -LabName University -ImageName "UnivImage" -Size "Standard_A2_v2"

.EXAMPLE
    Manage-AzureDtlFixedPool -LabName University -ImageName "UnivImage" -location "centralus" -TimeZoneId "Central Standard Time" -BatchSize 30

.NOTES

#>
[cmdletbinding()]
param 
(
    [Parameter(Mandatory = $true, HelpMessage = "Name of Lab")]
    [string] $LabName,

    [Parameter(Mandatory = $true, HelpMessage = "Name of base image in lab")]
    [string] $ImageName,

    [Parameter(Mandatory = $false, HelpMessage = "How many VMs to create in each batch")]
    [int] $BatchSize = 30,

    [Parameter(Mandatory = $false, HelpMessage = "Path to the Deployment Template File")]
    [string] $TemplatePath = ".\dtl_multivm_customimage.json",

    [Parameter(Mandatory = $false, HelpMessage = "Path to the Shutdown file")]
    [string] $ShutdownPath = ".\dtl_shutdown.json",

    [Parameter(Mandatory = $false, HelpMessage = "Size of VM image")]
    [string] $Size = "Standard_DS2_v2",    

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

$errors = @()

try {

    $credentialsKind = InferCredentials

    if ($credentialsKind -eq "Runbook") {
        $path = Get-AutomationVariable -Name 'TemplatePath'
        $file = Invoke-WebRequest -Uri $path -UseBasicParsing
        $templateContent = $file.Content
    }
    else {
        $path = Resolve-Path $TemplatePath
        $templateContent = [IO.File]::ReadAllText($path)
    }

    if ($BatchSize -gt 100) {
        throw "BatchSize must be less or equal to 100"
    }
    
    LogOutput "Start management ..."

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


    # Get size of the managed pool
    $Lab = GetLab -LabName $LabName
    $poolSize = $null
    # Hack for runbook
    if ($credentialsKind -eq "Runbook") {
        LogOutput "In runbook"
        foreach ($tag in $Lab.Tags) {
            if ($tag.ContainsValue("PoolSize")) {
                $poolSize = $tag.Get_Item("Value")
                break
            }
        }
    }
    else {
        $poolSize = $Lab.Tags.PoolSize
    }
    if (! $poolSize) {
        throw "The lab $LabName doesn't contain a PoolSize tag"
    }

    LogOutput "Pool size: $poolSize"

    [array] $vms = GetAllLabVMsExpanded -LabName $LabName
    [array] $failedVms = $vms | ? { $_.Properties.provisioningState -eq 'Failed' }
    [array] $claimedVms = $vms | ? { !$_.Properties.AllowClaim -and $_.Properties.OwnerObjectId }

    $availableVms = $vms.count - $claimedVms.count - $failedVms.count
    $vmToCreate = $poolSize - $availableVms

    LogOutput "Lab $LabName, Total VMS:$($vms.count), Failed:$($failedVms.count), Claimed:$($claimedVms.count), PoolSize: $poolSize, ToCreate: $vmToCreate"

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

    # Create VMs to refill the pool
    if ($vmToCreate -gt 0) {
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

        $loops = [math]::Floor($vmToCreate / $BatchSize)
        $rem = $vmToCreate - $loops * $BatchSize
        LogOutput "VMCount: $vmToCreate, Loops: $loops, Rem: $rem"

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
    LogOutput "Check for failed VMs and stopped VMs"
    [array] $vms = GetAllLabVMsExpanded -LabName $LabName
    [array] $failedVms = $vms | ? { $_.Properties.provisioningState -eq 'Failed' }
    [array] $stoppedVms = $claimedVms | ? { (GetDtlVmStatus -vm $_) -eq 'PowerState/deallocated'}
    $toDelete = $failedVms + $stoppedVms

    LogOutput "Failed:$($failedVms.Count), Stopped: $($stoppedVms.Count), ToDelete: $($toDelete.Count)"

    RemoveBatchVms -vms $toDelete -batchSize $batchSize -credentialsKind $credentialsKind -profilePath $profilePath
    LogOutput "Deleted $($toDelete.Count) VMs"

    LogOutput "All done!"

} finally {
    if ($credentialsKind -eq "File") {
        1..3 | % { [console]::beep(2500, 300) } # Make a sound to indicate we're done if running from command line.
    }
    popd
}
