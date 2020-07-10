<#
The MIT License (MIT)
Copyright (c) Microsoft Corporation  
Permission is hereby granted, free of charge, to any person obtaining a copy of this software and associated documentation files (the "Software"), to deal in the Software without restriction, including without limitation the rights to use, copy, modify, merge, publish, distribute, sublicense, and/or sell copies of the Software, and to permit persons to whom the Software is furnished to do so, subject to the following conditions:
The above copyright notice and this permission notice shall be included in all copies or substantial portions of the Software.  
THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE. 
.SYNOPSIS
Some Utility functions used by the domain join scripts.
#>

# AzLab Module dependency
$AzLabServicesModuleName = "Az.LabServices.psm1"
$AzLabServicesModuleSource = "https://raw.githubusercontent.com/Azure/azure-devtestlab/master/samples/ClassroomLabs/Modules/Library/Az.LabServices.psm1"
$global:AzLabServicesModulePath = Join-Path -Path (Resolve-Path ./) -ChildPath $AzLabServicesModuleName

# TODO Download secondary scripts
$global:JoinAzLabADStudentRenameVmScriptName = "Join-AzLabADStudent_RenameVm.ps1"
$global:JoinAzLabADStudentJoinVmScriptName = "Join-AzLabADStudent_JoinVm.ps1"
$global:JoinAzLabADStudentAddStudentScriptName = "Join-AzLabADStudent_AddStudent.ps1"
$global:JoinAzLabADStudentEnrollMDMScriptName = "Join-AzLabADStudent_EnrollMDM.ps1"

function Import-RemoteModule {
    param(
        [parameter(Mandatory = $true, ValueFromPipelineByPropertyName = $true, HelpMessage = "Web source of the psm1 file")]
        [ValidateNotNullOrEmpty()]
        [string] $Source,
        [parameter(Mandatory = $true, ValueFromPipelineByPropertyName = $true, HelpMessage = "Name of the module")]
        [ValidateNotNullOrEmpty()]
        [string] $ModuleName,
        [parameter(Mandatory = $false, ValueFromPipelineByPropertyName = $true, HelpMessage = "Whether to update and replace an existing psm1 file")]
        [switch]
        $Update = $false
    )
  
    $modulePath = Join-Path -Path (Resolve-Path ./) -ChildPath $ModuleName
  
    if ($Update -Or !(Test-Path -Path $modulePath)) {

        Remove-Item -Path $modulePath -ErrorAction SilentlyContinue

        $WebClient = New-Object System.Net.WebClient
        $WebClient.DownloadFile($Source, $modulePath)
    }
    
    Import-Module $modulePath
}
  
function Import-AzLabModule {
    param(
        [parameter(Mandatory = $false, ValueFromPipelineByPropertyName = $true, HelpMessage = "Whether to update an existing Az.LabServices module")]
        [switch]
        $Update = $false
    )

    Import-RemoteModule -Source $AzLabServicesModuleSource -ModuleName $AzLabServicesModuleName -Update:$Update
}

function Write-LogFile {
    param(
        [Parameter(Mandatory = $true)]
        [string] $Message
    )
 
    # Get the current date
    $LogDate = (Get-Date).tostring("yyyyMMdd")

    $CurrentDir = (Resolve-Path .\).Path
	$ScriptName = @(Get-PSCallStack)[1].InvocationInfo.MyCommand.Name

    # Frame Log File with Current Directory and date
    $LogFile = $CurrentDir + "\" + "$ScriptName`_$LogDate" + ".txt"

    # Add Content to the Log File
    $TimeStamp = (Get-Date).toString("dd/MM/yyyy HH:mm:ss:fff tt")
    $Line = "$TimeStamp - $Message"
    Add-content -Path $Logfile -Value $Line -ErrorAction SilentlyContinue

    Write-Output "Message: '$Message' has been logged to file: $LogFile"
}

function Register-ScheduledScriptTask {
    param(

        [parameter(Mandatory = $true, ValueFromPipelineByPropertyName = $true, HelpMessage = "Name of the scheduled task")]
        [string]
        $TaskName,

        [parameter(Mandatory = $true, ValueFromPipelineByPropertyName = $true, HelpMessage = "Path to the .ps1 script")]
        [string]
        $ScriptPath,
        
        [parameter(Mandatory = $false, ValueFromPipelineByPropertyName = $true, HelpMessage = "Arguments to the .ps1 script")]
        [string]
        $Arguments = "",

        [parameter(Mandatory = $false, ValueFromPipelineByPropertyName = $true, HelpMessage = "Local Account username")]
        [string]
        $LocalUser,

        [parameter(Mandatory = $false, ValueFromPipelineByPropertyName = $true, HelpMessage = "Local Account password")]
        [string]
        $LocalPassword,

        [parameter(Mandatory = $false, ValueFromPipelineByPropertyName = $true, HelpMessage = "Event triggering the task (Startup, Logon, Shutdown, Logoff)")]
        [ValidateSet("Startup","Logon","Shutdown","Logoff")] 
        [string] $EventTrigger,

        [parameter(Mandatory = $false, ValueFromPipelineByPropertyName = $true, HelpMessage = "Specifies an array of one or more trigger objects that start a scheduled task. A task can have a maximum of 48 triggers")]
        [CimInstance[]] 
        $TimeTrigger,

        [parameter(Mandatory = $false, ValueFromPipelineByPropertyName = $true, HelpMessage = "Specifies a configuration that the Task Scheduler service uses to determine how to run a task")]
        [CimInstance] 
        $Settings,

        [parameter(Mandatory = $false, ValueFromPipelineByPropertyName = $true, HelpMessage = "Whether to execute the command as SYSTEM")]
        [switch]
        $AsSystem = $false,

        [parameter(Mandatory = $false, ValueFromPipelineByPropertyName = $true, HelpMessage = "Whether to run the script once if successful")]
        [switch]
        $RunOnce = $false,

        [parameter(Mandatory = $false, ValueFromPipelineByPropertyName = $true, HelpMessage = "Whether to restart the system upon succesful completion")]
        [switch]
        $Restart = $false
    )

    $scriptDirectory = Split-Path $ScriptPath
    
    $runOnceCommand = ""
    if ($RunOnce) {
        $runOnceCommand = "; Unregister-ScheduledTask -TaskName '$TaskName' -Confirm:`$false"
    }

    $restartCommand = ""
    if ($Restart) {
        $restartCommand = "; Restart-Computer -Force"
    }

    $taskActionArgument = "-ExecutionPolicy Bypass -Command `"try { . '$scriptPath' $Arguments $runOnceCommand $restartCommand } catch { Write `$_.Exception.Message | Out-File ScheduledScriptTask_Log.txt } finally { } `""
    $taskAction = New-ScheduledTaskAction -Execute "$PSHome\powershell.exe" -Argument $taskActionArgument -WorkingDirectory $scriptDirectory
    
    $params = @{
        Force    = $True
        Action   = $taskAction
        RunLevel = "Highest"
        TaskName = $TaskName
    }

    if ($EventTrigger -eq "Startup") {
        $taskTrigger = New-ScheduledTaskTrigger -AtStartup
    }
    elseif ($EventTrigger -eq "Logon") {
        $taskTrigger = New-ScheduledTaskTrigger -AtLogOn
    }
    # TODO add support for Shutdown and Logoff triggers through eventID: https://community.spiceworks.com/how_to/123434-run-powershell-script-on-windows-event

    if ($TimeTrigger) {
        $taskTrigger += $TimeTrigger
    }

    if ($taskTrigger) {
        $params.Add("Trigger", $taskTrigger)
    }

    if ($Settings) {
        $params.Add("Settings", $Settings)
    }

    if ($AsSystem) {
        $params.Add("User", "NT AUTHORITY\SYSTEM")
    }
    else {
        $params.Add("User", $LocalUser)
        $params.Add("Password", $LocalPassword)
    }

    Register-ScheduledTask @params
}

function Register-AzLabADStudentTask {
    param(
        [parameter(Mandatory = $true, HelpMessage = "Resource group name of Lab Account.", ValueFromPipeline = $true)]
        [ValidateNotNullOrEmpty()]
        $LabAccountResourceGroupName,

        [parameter(Mandatory = $true, HelpMessage = "Name of Lab Account.", ValueFromPipeline = $true)]
        [ValidateNotNullOrEmpty()]
        $LabAccountName,
    
        [parameter(Mandatory = $true, ValueFromPipelineByPropertyName = $true, HelpMessage = "Name of Lab.")]
        [ValidateNotNullOrEmpty()]
        $LabName,

        [parameter(Mandatory = $true, HelpMessage = "1 or more AD Domain Service addresses (Domain Controller).", ValueFromPipeline = $true)]
        [ValidateNotNullOrEmpty()]
        [string[]] $DomainServiceAddress,

        [parameter(Mandatory = $true, HelpMessage = "Domain Name (e.g. contoso.com).", ValueFromPipeline = $true)]
        [ValidateNotNullOrEmpty()]
        [string] $Domain,

        [parameter(Mandatory = $true, ValueFromPipelineByPropertyName = $true, HelpMessage = "Local User created when setting up the Lab")]
        [ValidateNotNullOrEmpty()]
        [string] $LocalUser,

        [parameter(Mandatory = $true, ValueFromPipelineByPropertyName = $true, HelpMessage = "Domain User (e.g. CONTOSO\frbona or frbona@contoso.com). It must have permissions to add computers to the domain.")]
        [ValidateNotNullOrEmpty()]
        [string] $DomainUser,

        [parameter(Mandatory = $true, ValueFromPipelineByPropertyName = $true, HelpMessage = "Password of the Local User.")]
        [ValidateNotNullOrEmpty()]
        [string] $LocalPassword,

        [parameter(Mandatory = $true, ValueFromPipelineByPropertyName = $true, HelpMessage = "Password of the Domain User.")]
        [ValidateNotNullOrEmpty()]
        [string] $DomainPassword,

        [parameter(Mandatory = $false, ValueFromPipelineByPropertyName = $true, HelpMessage = "OUPath")]
        [string]
        $OUPath,
        
        [parameter(Mandatory = $false, ValueFromPipelineByPropertyName = $true, HelpMessage = "Whether to enroll the VMs to Intune (for Hybrid AD only)")]
        [switch]
        $EnrollMDM = $false,

        [parameter(Mandatory = $false, ValueFromPipelineByPropertyName = $true, HelpMessage = "Name of the script")]
        [string]
        $ScriptName
    )

    # Serialize arguments for the scheduled startup script
    $domainServiceAddressStr = New-SerializedStringArray $DomainServiceAddress
    
    # Domain join script to run at next startup
    $nextScriptPath = Join-Path (Resolve-Path .\).Path $ScriptName
    $nextTaskName = "Scheduled Task - " + $ScriptName

    $nextScriptArgs =
@"
-LabAccountResourceGroupName '$($LabAccountResourceGroupName)'
-LabAccountName '$($LabAccountName)'
-LabName '$($LabName)'
-DomainServiceAddress $domainServiceAddressStr
-Domain '$Domain'
-LocalUser '$LocalUser'
-DomainUser '$DomainUser'
-LocalPassword '$LocalPassword'
-DomainPassword '$DomainPassword'
-OUPath '$OUPath'
-EnrollMDM:`$$EnrollMDM
-CurrentTaskName '$NextTaskName'
"@.Replace("`n", " ").Replace("`r", "")
    
    Write-LogFile("Schedule Script Task - '$nextTaskName'")
    # Schedule next startup task
    Register-ScheduledScriptTask `
            -TaskName $nextTaskName `
            -ScriptPath $nextScriptPath `
            -Arguments $nextScriptArgs `
            -LocalUser $LocalUser `
            -LocalPassword $LocalPassword `
            -EventTrigger Startup
}

function Get-UniqueStudentVmName {
    param(
        [ValidateNotNullOrEmpty()]
        [string] $TemplateVmName,
        
        [ValidateNotNullOrEmpty()]
        [string] $StudentVmName
    )

    $TemplateVmId = $TemplateVmName.Replace("ML-RefVm-", "")
    $StudentVmId = $StudentVmName.Replace("ML-EnvVm-", "")

    # Max Length for Computer name: 15
    # Student Vm name too long. Trunked to last 3 digits.
    # Name of the Template VM: ML-RefVm-924446 -> 924446
    # Name of a VM in the VM pool: ML-EnvVm-987312527 -> 987312527
    # First 9 digits for Pool VM. Second 6 digits for Template

    # TODO convert 1st digit to ASCII character

    # Computer name cannot start with a digit. Prepending a 'M'. Last digit of $TemplateVmId is left out.
    return "M" + $StudentVmId + $TemplateVmId
}

function Get-AzLabCurrentTemplateVm {
    # The Azure Instance Metadata Service (IMDS) provides information about currently running virtual machine instances
    $computeVmId = Invoke-RestMethod -Headers @{"Metadata" = "true" } -URI "http://169.254.169.254/metadata/instance/compute/vmId?api-version=2019-11-01&format=text" -Method Get -TimeoutSec 5 
    # Correlate by VM id
    $templateVm = Get-AzLabAccount | Get-AzLab | Get-AzLabTemplateVM | Where-Object { $_.properties.resourceSettings.referenceVm.computeVmId -eq $computeVmId }

    if ($null -eq $templateVm) {
        # Script was run from a Student VM or another VM outside of this Lab.
        throw "Script must be run from the Template VM"
    }

    return $templateVm
}

# Ideally to be used only once from the Template if we don't uniquely know the Lab. O(LA*LAB*VM)
function Get-AzLabCurrentStudentVm {
    # The Azure Instance Metadata Service (IMDS) provides information about currently running virtual machine instances
    $computeVmId = Invoke-RestMethod -Headers @{"Metadata" = "true" } -URI "http://169.254.169.254/metadata/instance/compute/vmId?api-version=2019-11-01&format=text" -Method Get -TimeoutSec 5 
    # Correlate by VM id
    $studentVm = Get-AzLabAccount | Get-AzLab | Get-AzLabVm | Where-Object { $_.properties.resourceSets.computeVmId -eq $computeVmId }

    if ($null -eq $studentVm) {
        # Script was run from a Student VM or another VM outside of this Lab.
        throw "Script must be run from a Student VM"
    }

    return $studentVm
}

# To be used from the Student VM where we already know the Lab. O(VM)
function Get-AzLabCurrentStudentVmFromLab {
    param(
        [parameter(Mandatory = $true, ValueFromPipeline = $true, HelpMessage = "VM claimed by user")]
        [ValidateNotNullOrEmpty()]
        $Lab
    )
    # The Azure Instance Metadata Service (IMDS) provides information about currently running virtual machine instances
    $computeVmId = Invoke-RestMethod -Headers @{"Metadata" = "true" } -URI "http://169.254.169.254/metadata/instance/compute/vmId?api-version=2019-11-01&format=text" -Method Get -TimeoutSec 5 
    # Correlate by VM id
    $studentVm = $Lab | Get-AzLabVm | Where-Object { $_.properties.resourceSets.computeVmId -eq $computeVmId }

    if ($null -eq $studentVm) {
        # Script was run from a Student VM or another VM outside of this Lab.
        throw "Script must be run from a Student VM"
    }

    return $studentVm
}

function Get-AzLabUserForCurrentVm {
    param(
        [parameter(Mandatory = $true, ValueFromPipeline = $true, HelpMessage = "Lab")]
        [ValidateNotNullOrEmpty()]
        $Lab,

        [parameter(Mandatory = $true, ValueFromPipeline = $true, HelpMessage = "VM claimed by user")]
        [ValidateNotNullOrEmpty()]
        $Vm
    )

    $Lab | Get-AzLabUser | Where-Object { $_.name -eq $Vm.properties.claimedByUserPrincipalId }
}

function Get-AzLabTemplateVmName {
    param(
        [parameter(Mandatory = $true, ValueFromPipeline = $true, HelpMessage = "Template VM")]
        [ValidateNotNullOrEmpty()]
        $TemplateVm
    )

    $results = $TemplateVm.properties.resourceSettings.referenceVm.vmResourceId | Select-String -Pattern '([^/]*)$'
    $results.Matches.Value | Select-Object -Index 0
}

function Get-AzureADJoinStatus {
    $status = dsregcmd /status 
    $status.Replace(":", ' ') | 
        ForEach-Object { $_.Trim() }  | 
        ConvertFrom-String -PropertyNames 'State', 'Status'
} 

function Join-DeviceMDM {
    param(
        [parameter(Mandatory = $false, ValueFromPipelineByPropertyName = $true, HelpMessage = "Whether to restart the system upon succesful completion")]
        [switch]
        $UseAADDeviceCredential = $false
    )

    if ($UseAADDeviceCredential){
        . "$env:windir\system32\deviceenroller.exe" /c /AutoEnrollMDMUsingAADDeviceCredential
    } else {
        . "$env:windir\system32\deviceenroller.exe" /c /AutoEnrollMDM
    }
}

function New-SerializedStringArray {
    param(
        [parameter(Mandatory = $true, ValueFromPipeline = $true, HelpMessage = "String Array")]
        [ValidateNotNullOrEmpty()]
        $Array
    )
    
    $ArrayStr = "'" + $Array[0] + "'"
    $Array | Select-Object -Skip 1 | ForEach-Object {
        $ArrayStr += ",'" + $_ + "'"
    }

    return $ArrayStr
}