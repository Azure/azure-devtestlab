param
(
    [Parameter(Mandatory=$true, HelpMessage="The Subscription Id that contains the source DevTest Lab for copying virtual machines")]
    [string] $SourceSubscriptionId,

    [Parameter(Mandatory=$true, HelpMessage="The name of the source DevTest Lab")]
    [string] $SourceDevTestLabName,

    [Parameter(HelpMessage="The name of the source Virtual Machine (located in the source DevTest Lab) to copy, if you omit this parameter all VMs will be copied")]
    [string] $SourceVirtualMachineName,

    [Parameter(HelpMessage="The name of the destination Virtual Machine in the case you want to use a different machine name when a SourceVirtualMachineName is specified")]
    [string] $DestinationVirtualMachineName,

    [Parameter(Mandatory=$true, HelpMessage="The Subscription Id that contains the destination DevTest Lab for copying virtual machines")]
    [string] $DestinationSubscriptionId,

    [Parameter(Mandatory=$true, HelpMessage="The name of the destination DevTest Lab")]
    [string] $DestinationDevTestLabName
)

# -----------------------------------------------------------------
# Function to select a subscription - we save a little time only switching if we're not already on that subscription
# -----------------------------------------------------------------
function SelectSubscription($subId){
    # switch to another subscription assuming it's not the one we're already on
    if((Get-AzureRmContext).Subscription.Id -ne $subId){
        Write-Output "Switching to subscription $subId"
        $result = Set-AzureRmContext -SubscriptionId $subId
    }
}

# -----------------------------------------------------------------
# Function to Save profile, need this for Powershell jobs to pass authorization information
# -----------------------------------------------------------------
function SaveProfile {
    $profilePath = Join-Path $PSScriptRoot "profile.json"

    If (Test-Path $profilePath){
	    Remove-Item $profilePath
    }
    
    Save-AzureRmContext -Path $profilePath
}

# -----------------------------------------------------------------
# Function to Save profile, need this for Powershell jobs to pass authorization information
# -----------------------------------------------------------------
$copyVirtualMachineCodeBlock = {
    Param($profilePath, $sourceResourceId, $destinationLab, $destinationVirtualMachineName)
    
    # First need to re-hook up authorization to azure
    Import-AzureRmContext -Path $profilePath | Out-Null

    $resourceName = $destinationLab.Name
    $resourceType = "Microsoft.DevTestLab/labs"

    if ($DestinationVirtualMachineName -ne $null -and $DestinationVirtualMachineName -ne "") {
        $paramObject = @{ sourceVirtualMachineResourceId = "$($sourceResourceId)"; destinationVirtualMachineName = $DestinationVirtualMachineName }
    }
    else {
        $paramObject = @{ sourceVirtualMachineResourceId = "$($sourceResourceId)" }
    }

    # Invoke the API for importing a VM to another lab
    $status = Invoke-AzureRmResourceAction -Parameters $paramObject `
                                           -ResourceGroupName $destinationLab.ResourceGroupName `
                                           -ResourceType $resourceType `
                                           -ResourceName $resourceName `
                                           -Action "importVirtualMachine" `
                                           -ApiVersion 2017-04-26-preview `
                                           -Force
    
    # For writing nice output, we extract the source info from the Resource Id
    $sourceResourceIdSplit = $sourceResourceId.Split('/')
    $sourceLabName = $sourceResourceIdSplit[$sourceResourceIdSplit.Count - 3]
    $sourceVmName = $sourceResourceIdSplit[$sourceResourceIdSplit.Count - 1]

    if ($status -ne $null -and $status.status -eq "Succeeded") {
        Write-Output "Successfully migrated VM '$sourceVmName' from Lab '$sourceLabName' to Lab '$($destinationLab.Name)'"
    }
    else {
        Write-Error "Failed to migrate VM '$sourceVmName' from Lab '$sourceLabName' to Lab '$($destinationLab.Name)'"
    }
}

# -----------------------------------------------------------------
# Validate Parameters
# -----------------------------------------------------------------

# During validation - we stop if we encounter any errors
$ErrorActionPreference = "Stop"

Write-Output "Validating Parameters... "

$sub = Select-AzureRmSubscription -SubscriptionId $SourceSubscriptionId
if ($sub -eq $null) {
    Write-Error "Unfortunately the logged in user doesn't have access to subscription Id $SourceSubscriptionId .  Perhaps you need to login with Add-AzureRmAccount?"
}

$sourceLab = Find-AzureRmResource -ResourceNameEquals $SourceDevTestLabName -ResourceType "Microsoft.DevTestLab/labs"

if ($sourceLab -eq $null) {
    Write-Error "'$SourceDevTestLabName' Lab doesn't exist, cannot copy any Virtual Machines from this source"
}

if ($SourceVirtualMachineName -ne $null -and $SourceVirtualMachineName -ne '') {
    $sourceVirtualMachine = Find-AzureRmResource -ResourceNameEquals "$SourceDevTestLabName/$SourceVirtualMachineName" -ResourceType "Microsoft.DevTestLab/labs/virtualmachines"
    if ($sourceVirtualMachine -eq $null) {
        Write-Error "$SourceVirtualMachineName VM doesn't exist in $SourceDevTestLabName , unable to copy this VM to destination lab $DestinationDevTestLabName"
    }
}

if ($DestinationVirtualMachineName -ne $null -and $DestinationVirtualMachineName -ne '') {
    # Just confirm that if we have a destination machine name, that we also have a source machine name
    if ($SourceVirtualMachineName -eq $null -or $SourceVirtualMachineName -eq '') {
        Write-Error "Unable to use DestinationVirtualMachineName parameter without also specifying the SourceVirtualMachineName parameter."
    }
}


if ($SourceSubscriptionId -ne $DestinationSubscriptionId) {
    $sub = Select-AzureRmSubscription -SubscriptionId $DestinationSubscriptionId

    if ($sub -eq $null) {
        Write-Error "Unfortunately the logged in user doesn't have access to subscription Id $DestinationSubscriptionId .  Perhaps you need to login with Add-AzureRmAccount?"
    }
}

$destinationLab = Find-AzureRmResource -ResourceNameEquals $DestinationDevTestLabName -ResourceType "Microsoft.DevTestLab/labs"
if ($destinationLab -eq $null) {
    Write-Error "'$DestinationDevTestLabName' Lab doesn't exist, cannot copy any Virtual Machines to this destination"
}

# -----------------------------------------------------------------
# Parameters are good if we made it here, now we initiate the copy
# -----------------------------------------------------------------

# Let's continue on error so we can get try to copy each of the Virtual machines, in case just one fails
$ErrorActionPreference = "Continue"
Write-Output "Starting the jobs to import VMs... "

$sourceResourceIds = @()

if ($sourceVirtualMachine -ne $null) {
    # We have a single VM to copy
    $sourceResourceIds += $sourceVirtualMachine.ResourceId
}
else {

    # Switch back to the source subscription to get the list of VMs
    SelectSubscription $SourceSubscriptionId

    # We need to copy all the VMs in the lab
    Get-AzureRmResource `
            -ResourceType "Microsoft.DevTestLab/labs/virtualmachines" `
            -ResourceGroupName $sourceLab.ResourceGroupName `
            | ForEach-Object {
                $sourceResourceIds += $_.ResourceId
            }
}

# Switch back to the destination subscription to start moving VMs
SelectSubscription $DestinationSubscriptionId
SaveProfile
$profilePath = Join-Path $PSScriptRoot "profile.json"

# kick off all the jobs in parallel and then wait for results
$jobs = @()

if ($sourceResourceIds.Count -eq 1) {
    # if the source VM was specifed (results in only 1 source Id) we can also rename the VM
    $jobs += Start-Job -ScriptBlock $copyVirtualMachineCodeBlock -ArgumentList $profilePath, $sourceResourceIds[0], $destinationLab, $DestinationVirtualMachineName

}
else {
    $sourceResourceIds | ForEach-Object {
        $jobs += Start-Job -ScriptBlock $copyVirtualMachineCodeBlock -ArgumentList $profilePath, $_, $destinationLab 
    }
}

Write-Output "Waiting for $($jobs.Count) virtual machine import job(s) to complete."
$jobs | ForEach-Object { Receive-Job $_ -Wait  | Write-Output }
$jobs | Remove-Job
