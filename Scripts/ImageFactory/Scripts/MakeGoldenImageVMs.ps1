param
(
    [Parameter(Mandatory=$true, HelpMessage="The location of the factory configuration files")]
    [string] $ConfigurationLocation,
    
    [Parameter(Mandatory=$true, HelpMessage="The name of the lab")]
    [string] $DevTestLabName,
    
    [Parameter(Mandatory=$true, HelpMessage="The admin username for the VM")]
    [string] $machineUserName,
    
    [Parameter(Mandatory=$true, HelpMessage="The admin password for the VM")]
    [System.Security.SecureString] $machinePassword,
    
    [Parameter(Mandatory=$true, HelpMessage="The number of minutes to wait before timing out Azure operations")]
    [int] $StandardTimeoutMinutes,

    [Parameter(Mandatory=$true, HelpMessage="The name of the lab")]
    [string] $vmSize,

    [Parameter(HelpMessage="Specifies whether or not to sysprep the created VMs")]
    [boolean] $includeSysprep = $true
        
)

function IsVirtualMachineReady ($vmName, $status)
{
    $retval = $false

    if ($status.Count -lt 1) {
        Write-Output ($vmName + " current has no status provided")
    }
    elseif ($status.Count -eq 1) {
        Write-Output ($vmName + " currently has status of " +  $status[0].Code)
    }
    elseif ($status.Count -gt 1) {
        Write-Output ($vmName + " currently has status of " +  $status[0].Code + " and " + $status[1].Code)
    }
    
    if ($status.Count -gt 1) {
        # We have both parameters (provisioning state + power state) - this is the default case
        if (($status[0].Code -eq "ProvisioningState/succeeded") -and ($status[1].Code -eq "PowerState/deallocated")) {
            $retval = $true
        }
        elseif (($status[1].Code -eq "ProvisioningState/succeeded") -and ($status[0].Code -eq "PowerState/deallocated")) {
            $retval = $true
        }
    }

    return $retval
}

#resolve any relative paths in ConfigurationLocation 
$ConfigurationLocation = (Resolve-Path $ConfigurationLocation).Path

$modulePath = Join-Path (Split-Path ($Script:MyInvocation.MyCommand.Path)) "DistributionHelpers.psm1"
Import-Module $modulePath
$scriptFolder = Split-Path $Script:MyInvocation.MyCommand.Path
$makeVmScriptLocation = Join-Path $scriptFolder "MakeVM.ps1"
$imageListLocation = Join-Path $ConfigurationLocation "GoldenImages"
$files = Get-ChildItem $imageListLocation -Recurse -Filter "*.json"
$createdVms = New-Object System.Collections.ArrayList

#kick off jobs to deploy all the VMs in parallel
$jobs = @()
SaveProfile

$usedVmNames = @()

foreach ($file in $files)
{
    #grab the image path relative to the GoldenImages folder
    $imagePath = $file.FullName.Substring($imageListLocation.Length + 1)

    #determine a VM name for each file
    $vmName = $file.BaseName.Replace("_", "").Replace(" ", "").Replace(".", "")
    $intName = 0
    if ([System.Int32]::TryParse($vmName, [ref]$intName))
    {
        Write-Output "Adding prefix to vm named $vmName because it cannot be fully numeric"
        $vmName = ('vm' + $vmName)
    }

    if($vmName.Length -gt 15){
        $shortenedName = $vmName.Substring(0, 13)
        Write-Output "VM name $vmName is too long. Shortening to $shortenedName"
        $vmName = $shortenedName
    }

    while ($usedVmNames.Contains($vmName)){
        $nameRoot = $vmName
        if($vmName.Length -gt 12){
            $nameRoot = $vmName.Substring(0, 12)
        }
        $updatedName = $nameRoot + (Get-Random -Minimum 1 -Maximum 999).ToString("000")
        Write-Output "VM name $vmName has already been used. Reassigning to $updatedName"
        $vmName = $updatedName
    }
    $usedVmNames += $vmName

    Write-Output "Starting job to create a VM named $vmName for $imagePath"
    $jobs += Start-Job -Name $file.Name -FilePath $makeVmScriptLocation -ArgumentList $modulePath, $file.FullName, $DevTestLabName, $vmName, $imagePath, $machineUserName, $machinePassword, $vmSize, $includeSysprep
}

$jobCount = $jobs.Count
Write-Output "Waiting for $jobCount VM creation jobs to complete"
foreach ($job in $jobs){
    $jobOutput = Receive-Job $job -Wait
    Write-Output $jobOutput
    $createdVMName = $jobOutput[$jobOutput.Length - 1]
    if($createdVMName){
        $createdVms.Add($createdVMName)
    }
}
Remove-Job -Job $jobs

#get machines that show up in the VM blade so we can apply the GoldenImage Tag
$allVms = Find-AzureRmResource -ResourceType "Microsoft.Compute/virtualMachines"

for ($index = 0; $index -lt $createdVms.Count; $index++){
    $currentVmName = $createdVms[$index]
    $currentVmValue = $allVms | Where-Object {$_.Name -eq $currentVmName -and $_.ResourceGroupName.StartsWith($DevTestLabName, "CurrentCultureIgnoreCase")}
    if(!$currentVmValue){
        Write-Error "##[error]$currentVmName was not created successfully. It does not appear in the VM blade"
        continue;
    }

    #wait for the machine to get to the correct state
    $stopWaiting = $false
    $stopTime = Get-Date
    $stopTime = $stopTime.AddMinutes($StandardTimeoutMinutes);

    while ($stopWaiting -eq $false) {
         
        $vm = Get-AzureRmVM -ResourceGroupName $currentVmValue.ResourceGroupName -Name $currentVmValue.ResourceName -Status
        $currentTime = Get-Date

        if (IsVirtualMachineReady -vmName $vm.Name -status $vm.Statuses) {
            $stopWaiting = $true;
        }
        elseif ($currentTime -gt $stopTime){
            $stopWaiting = $true;
            Write-Error "##[error]Creation of $CurrentVmName has timed out"
        }
        else {
            #pause a bit before we try again
            if ($vm.Statuses.Count -eq 0) {
                Write-Output ($vm.Name + " has no status listed. Sleeping before checking again")
            }
            elseif ($vm.Statuses.Count -eq 1) {
                Write-Output ($vm.Name + " currently has status of " +  $vm.Statuses[0].Code + ". Sleeping before checking again")
            }
            else {
                Write-Output ($vm.Name + " currently has status of " +  $vm.Statuses[0].Code + " and " + $vm.Statuses[1].Code + ". Sleeping before checking again")
            }

            Start-Sleep -Seconds 30
        }
    }
}
    
#sleep a bit to make sure the VM creation and tagging is complete
Start-Sleep -Seconds 10
