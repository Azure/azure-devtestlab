<#
.SYNOPSIS 
    This script deallocates every stopped Azure virtual machines.

.DESCRIPTION
    This script deallocates every Azure virtual machines which are stopped (i.e. the machine you stop from the OS and not
    the Azure portal, therefore you still pay for it) in the specified DevTest Lab.

.PARAMETER LabName
    Mandatory. The name of the Dev Test Lab to run the machine deallocation on.

.PARAMETER profilePath
    Optional. Path to file with Azure Profile. How to generate this file is explained at the end of the Readme for the repo (https://github.com/lucabol/University).
    Default "$env:APPDATA\AzProfile.txt".

.EXAMPLE
    DeallocateStoppedVM -LabName University -profilePath "c:\AzProfile.txt"

.EXAMPLE
    DeallocateStoppedVM -LabName University

.NOTES

#>
Param
(
    # Lab Name
    [Parameter(Mandatory = $true, HelpMessage = "Name of Lab")]
    [string] $LabName,

    [Parameter(Mandatory = $false, HelpMessage = "Path to file with Azure Profile")]
    [string] $profilePath = "$env:APPDATA\AzProfile.txt"
)

. .\Common.ps1

$VerbosePreference = "continue"


$credentialsKind = InferCredentials
LogOutput "Credentials: $credentialsKind"

LoadAzureCredentials -credentialsKind $credentialsKind -profilePath $profilePath

#we have to find the RG of the compute VM, which is different from the RG of the lab and the labVM

#get the expanded properties of the VMs
$labVMs = GetAllLabVMsExpanded -LabName $LabName


foreach ($vm in $labVMs) {

    #get the actual RG of the compute VM
    $labVmRGName = (Get-AzureRmResource -Id $vm.Properties.computeid).ResourceGroupName

    $VMStatus = (Get-AzureRmVM -ResourceGroupName $labVmRGName -Name $VM.Name -Status).Statuses.Code[1]

    Write-Verbose ("Status VM  " + $VM.Name + " :" + $VMStatus)
            
    if ($VMStatus -eq 'PowerState/deallocated') {
        Write-Output ($VM.Name + " is already deallocated")
    }

    elseIf ($VMStatus -eq 'PowerState/stopped') {
        #force the VM deallocation
        Stop-AzureRmVM -Name $VM.Name -ResourceGroupName $labVmRGName -Force
        # We could also remove the VM here instead of just deallocating it

    }

}
