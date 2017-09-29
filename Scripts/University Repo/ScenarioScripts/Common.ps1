#### PS utility functions
# Stop at first error
$ErrorActionPreference = "Stop"
pushd $PSScriptRoot

# Workaround to set verbose everywhere
$global:VerbosePreference = $VerbosePreference
$ProgressPreference = $VerbosePreference # Disable Progress Bar

# Print nice error
function Report-Error {
    <#
    .SYNOPSIS 
        Print nice error

    .DESCRIPTION
        Print nice error

    .PARAMETER error
        Mandatory. The error message.

    .NOTES

    #>
    [CmdletBinding()]
    param($error)

    LogOutput "In ReportError"
    $posMessage = $error.ToString() + "`n" + $error.InvocationInfo.PositionMessage
    Write-Error "`nERROR: $posMessage" -ErrorAction "Continue"
}

# Print error before exiting
function Handle-LastError {
    <#
    .SYNOPSIS 
        Print error before exiting

    .DESCRIPTION
        Print error before exiting

    .NOTES
        IMPORTANT NOTE: Throwing a terminating error (using $ErrorActionPreference = "Stop") still
        returns exit code zero from the PowerShell script when using -File. The workaround is to
        NOT use -File when calling this script and leverage the try-catch-finally block and return
        a non-zero exit code from the catch block.
    #>
    [CmdletBinding()]
    param()

    Report-Error -error $_
    LogOutput "All done!"
    # IMPORTANT NOTE: Throwing a terminating error (using $ErrorActionPreference = "Stop") still
    # returns exit code zero from the PowerShell script when using -File. The workaround is to
    # NOT use -File when calling this script and leverage the try-catch-finally block and return
    # a non-zero exit code from the catch block.
    exit -1
}

# Common logging function
function LogOutput {   
    <#
    .SYNOPSIS 
        Write log to output

    .DESCRIPTION
        Write log to output

    .PARAMETER msg
        Mandatory. The message to be output in the log.

    .NOTES

    #>        
    [CmdletBinding()]
    param($msg)
    $timestamp = (Get-Date).ToUniversalTime()
    $output = "$timestamp [INFO]:: $msg"    
    Write-Verbose $output
}

### Azure utility functions

# So that we can select which API to call when they get updated
function GetAzureModuleVersion {
    <#
    .SYNOPSIS 
        Retrieve the azure module version

    .DESCRIPTION
        Retrieve the azure module version so it's possible to select which API to call
    .NOTES

    #>
    [CmdletBinding()]
    param()
    $az = (Get-Module -ListAvailable -Name Azure).Version
    LogOutput "Azure Version: $az"
    return $az   
}

# Are we running in Azure Automation?
function InferCredentials {
    <#
    .SYNOPSIS 
        Detect the current environment

    .DESCRIPTION
        Detect the current environment between Runbook and File
    .NOTES

    #>
    [CmdletBinding()]
    param()
    if ($PSPrivateMetadata.JobId) {
        return "Runbook"
    }
    else {
        return "File"
    }
    
}

# Log in to Azure differently depending on where we are running
function LoadAzureCredentials {
    <#
    .SYNOPSIS 
        Log in to Azure differently depending on where the script is running

    .DESCRIPTION
        Log in to Azure differently depending on where the script is running

    .PARAMETER credentialsKind
        Mandatory. Type of credential. Accepted values are "File" or "RunBook"

    .PARAMETER profilePath
        Optional. Full path to the file containing the saved credentials.

    .NOTES
        In order to create the credential file to be used for the "File" credential kind do the following:

        In 'powershell' run the following commands,
        using the correct Subscription Id instead of XXXXX-XXXX-XXXX:

        Login-AzureRmAccount
        Set-AzureRmContext -SubscriptionId "XXXXX-XXXX-XXXX"
        Save-AzureRMProfile -Path "$env:APPDATA\AzProfile.txt"

        This saves the credentials file where the scripts look for.
    #>
    [CmdletBinding()]
    param($credentialsKind, $profilePath)

    Write-Verbose "Credentials Kind: $credentialsKind"
    Write-Verbose "Credentials File: $profilePath"

    if (($credentialsKind -ne "File") -and ($credentialsKind -ne "RunBook")) {
        throw "CredentialsKind must be either 'File' or 'RunBook'. It was $credentialsKind instead"
    }

    $azVer = GetAzureModuleVersion

    if ($credentialsKind -eq "File") {
        if (! (Test-Path $profilePath)) {
            throw "Profile file(s) not found at $profilePath. Exiting script..."    
        }
        if ($azVer -ge "3.8.0") {
            Import-AzureRmContext -Path $profilePath | Out-Null
        }
        else {
            Select-AzureRmProfile -Path $profilePath | Out-Null
        }
    }
    else {
        $connectionName = "AzureRunAsConnection"

        $servicePrincipalConnection = Get-AutomationConnection -Name $connectionName         

        Add-AzureRmAccount `
            -ServicePrincipal `
            -TenantId $servicePrincipalConnection.TenantId `
            -ApplicationId $servicePrincipalConnection.ApplicationId `
            -CertificateThumbprint $servicePrincipalConnection.CertificateThumbprint
        
        #Set-AzureRmContext -SubscriptionId $servicePrincipalConnection.SubscriptionID 
        Select-AzureRmSubscription -SubscriptionId $servicePrincipalConnection.SubscriptionID  | Write-Verbose

        # Save profile so it can be used later
        # TODO: consider cleaning it up so that it is a bit more encapsulated
        $global:profilePath = (Join-Path $env:TEMP  (New-guid).Guid)
        if ($azVer -ge "3.8.0") {
            Save-AzureRmContext -Path $global:profilePath | Write-Verbose
        }
        else {
            Save-AzureRmProfile -Path $global:profilePath | Write-Verbose
        }
    } 
}

### DTL utility functions

function GetLab {
    <#
    .SYNOPSIS 
        Return the lab resource

    .DESCRIPTION
        Return the lab resource object from the lab name

    .PARAMETER LabName
        Mandatory. The name of the lab

    .NOTES

    #>
    [CmdletBinding()]
    param($LabName)
    $lab = Find-AzureRmResource -ResourceType "Microsoft.DevTestLab/labs" -ResourceNameContains $LabName  | where ResourceName -EQ "$LabName"
    LogOutput "Lab: $lab"
    return $lab
}

function GetAllLabVMs {
    <#
    .SYNOPSIS 
        Returns all the VMs in the specified Lab

    .DESCRIPTION
        Returns all the VMs in the specified Lab

    .PARAMETER LabName
        Mandatory. The name of the lab

    .NOTES

    #>
    [CmdletBinding()]
    param($LabName)
    
    return Find-AzureRmResource -ResourceType 'Microsoft.DevTestLab/labs/virtualmachines' -ResourceNameContains "$LabName/" | ? { $_.ResourceName -like "$LabName/*" }
} 

# Get the expanded props as well (but slowly)
function GetAllLabVMsExpanded {
    <#
    .SYNOPSIS 
        Returns all the VMs in the specified Lab with all the properties

    .DESCRIPTION
        Returns all the VMs in the specified Lab with all the properties

    .PARAMETER LabName
        Mandatory. The name of the lab

    .NOTES
        This function can be slow due to the number of information retrieved for each VM
    #>
    [CmdletBinding()]
    param($LabName)

    return Find-AzureRmResource -ResourceType 'Microsoft.DevTestLab/labs/virtualmachines' -ResourceNameContains "$LabName/" -ExpandProperties | ? { $_.ResourceName -like "$LabName/*" }    
}

# Get to the RG name from lab name (it will break if multiple labs with same name are allowed)
function GetResourceGroupName {
    [CmdletBinding()]
    param($LabName)
    return (GetLab -labname $LabName).ResourceGroupName    
}

# Get status of VM inside a DTL
function GetDtlVmStatus {
    <#
    .SYNOPSIS 
        Get status of VM inside a DTL

    .DESCRIPTION
        Get status of VM inside a DTL

    .PARAMETER vm
        Mandatory. The name of the vm

    .NOTES

    #>
    [CmdletBinding()]
    param($vm)

    $computeGroup = ($vm.Properties.ComputeId -split "/")[4]
    $name = ($vm.Properties.ComputeId -split "/")[8]
    $compVM = Get-azurermvm -ResourceGroupName $computeGroup -name $name -Status

    return $compVM.Statuses.Code[1]
}

#### Removing VMs

# Function to return the Automation account information that this job is running in.
Function WhoAmI {
    <#
    .SYNOPSIS 
        Returns the Automation account information that this job is running in

    .DESCRIPTION
        Returns the Automation account information that this job is running in

    .NOTES

    #>
    $AutomationResource = Find-AzureRmResource -ResourceType Microsoft.Automation/AutomationAccounts

    foreach ($Automation in $AutomationResource) {
        $Job = Get-AzureRmAutomationJob -ResourceGroupName $Automation.ResourceGroupName -AutomationAccountName $Automation.Name -Id $PSPrivateMetadata.JobId.Guid -ErrorAction SilentlyContinue
        if (!([string]::IsNullOrEmpty($Job))) {
            $AutomationInformation = @{}
            $AutomationInformation.Add("SubscriptionId", $Automation.SubscriptionId)
            $AutomationInformation.Add("Location", $Automation.Location)
            $AutomationInformation.Add("ResourceGroupName", $Job.ResourceGroupName)
            $AutomationInformation.Add("AutomationAccountName", $Job.AutomationAccountName)
            $AutomationInformation.Add("RunbookName", $Job.RunbookName)
            $AutomationInformation.Add("JobId", $Job.JobId.Guid)
            $AutomationInformation
            break;
        }
    }
}

# Removes virtual machines given their names, how to batch parallelize them and credentials
function RemoveBatchVMs {
    <#
    .SYNOPSIS 
        Removes virtual machines given their names, how to batch parallelize them and credentials

    .DESCRIPTION
        Removes virtual machines given their names, how to batch parallelize them and credentials

    .PARAMETER vms
        Mandatory. The name of the VMs to be removed

    .PARAMETER BatchSize
        Mandatory. The size of the Batch of VMs

    .PARAMETER credentialsKind
        Mandatory. Type of credential. Accepted values are "File" or "RunBook"

    .PARAMETER profilePath
        Mandatory. Path to file with Azure Profile.

    .NOTES

    #>
    [CmdletBinding()]
    param($vms, $BatchSize, $credentialsKind, $profilePath)

    LogOutput "Removing VMs: $vms"

    if ($credentialsKind -eq "File") {
        $batch = @(); $i = 0;

        $vms | % {
            $batch += $_.ResourceId
            $i++
            if ($batch.Count -eq $BatchSize -or $vms.Count -eq $i) {
                LogOutput "We are in the File path"
                . .\Remove-AzureDtlLabVMs -Ids $batch -profilePath $profilePath

                if ($vms.Count -gt $i) {
                    LogOutput "Waiting between batches to avoid executing too many things in parallel"
                    Start-sleep -Seconds 240
                }
                $batch = @()
            }
        }
    }
    else {
        LogOutput "We are in the Runbook path"
        # Get Account information on where this job is running from
        $AccountInfo = WhoAmI
        $RunbookName = "Remove-AzureDtlLabVMs"

        # Process the list of VMs using the automation service and collect jobs used
        $Jobs = @()      
                                    
        foreach ($VM in $vms) {   
            # Start automation runbook to process VMs in parallel
            $RunbookNameParams = @{}
            $batch = @();
            $batch += $VM.ResourceId
            $RunbookNameParams.Add("Ids", $batch)
            $RunbookNameParams.Add("profilePath", $profilePath)
            # Loop here until a job was successfully submitted. Will stay in the loop until job has been submitted or an exception other than max allowed jobs is reached
            while ($true) {
                try {
                    $Job = Start-AzureRmAutomationRunbook -ResourceGroupName $AccountInfo.ResourceGroupName -AutomationAccountName $AccountInfo.AutomationAccountName -Name $RunbookName -Parameters $RunbookNameParams -ErrorAction Stop
                    $Jobs += $Job
                    # Submitted job successfully, exiting while loop
                    break
                }
                catch {
                    # If we have reached the max allowed jobs, sleep backoff seconds and try again inside the while loop
                    if ($_.Exception.Message -match "conflict") {
                        Write-Verbose ("Sleeping for 30 seconds as max allowed jobs has been reached. Will try again afterwards")
                        Start-Sleep 30
                    }
                    else {
                        throw $_
                    }
                }
            }
        }
                
        # Wait for jobs to complete, fail, or suspend (final states allowed for a runbook)
        $JobsResults = @()
        foreach ($RunningJob in $Jobs) {
            $ActiveJob = Get-AzureRMAutomationJob -ResourceGroupName $AccountInfo.ResourceGroupName -AutomationAccountName $AccountInfo.AutomationAccountName -Id $RunningJob.JobId
            While ($ActiveJob.Status -ne "Completed" -and $ActiveJob.Status -ne "Failed" -and $ActiveJob.Status -ne "Suspended") {
                Start-Sleep 30
                $ActiveJob = Get-AzureRMAutomationJob -ResourceGroupName $AccountInfo.ResourceGroupName -AutomationAccountName $AccountInfo.AutomationAccountName -Id $RunningJob.JobId
            }
            $JobsResults += $ActiveJob
        }
    }
}

### Creating VMs

function ConvertTo-Hashtable {
    <#
    .SYNOPSIS 
        Convert the Json object into an hashtable

    .DESCRIPTION
        Convert the Json object into an hashtable to be output

    .NOTES

    #>
    param(
        [Parameter(ValueFromPipeline)]
        [string] $Content
    )

    [void][System.Reflection.Assembly]::LoadWithPartialName("System.Web.Extensions")  
    $parser = New-Object Web.Script.Serialization.JavaScriptSerializer   
    Write-Output -NoEnumerate $parser.DeserializeObject($Content)
}

function Create-ParamsJson {
    <#
    .SYNOPSIS 
        Replace the tokenized values in file with content

    .DESCRIPTION
        Replace the tokenized values in JSON with content

    .PARAMETER Content
        Mandatory. Content to be replaced in the JSON

    .PARAMETER Tokens
        Mandatory. Token values to be used for replacement
    
    .PARAMETER Compress
        Optional. If true \r\n will be removed

    .NOTES

    #>
    [CmdletBinding()]
    Param(
        [string] $Content,
        [hashtable] $Tokens,
        [switch] $Compress
    )

    $replacedContent = (Replace-Tokens -Content $Content -Tokens $Tokens)
    
    if ($Compress) {
        return (($replacedContent.Split("`r`n").Trim()) -join '').Replace(': ', ':')
    }
    else {
        return $replacedContent
    }
}

# Create VMs from a json description substituting TOKEN for __TOKEN__
function Create-VirtualMachines {
    <#
    .SYNOPSIS 
        Create VMs from a json description substituting TOKEN for __TOKEN__

    .DESCRIPTION
        Create VMs from a json description substituting TOKEN for __TOKEN__

    .PARAMETER Content
        Mandatory. Content to be replaced in the JSON

    .PARAMETER LabId
        Mandatory. Unique Lab identifier

    .PARAMETER Tokens
        Mandatory. Token values to be used for replacement

    .NOTES

    #>
    [CmdletBinding()]
    Param(
        [string] $content,
        [string] $LabId,
        [hashtable] $Tokens
    )

    try {
        $json = Create-ParamsJson -Content $content -Tokens $tokens
        LogOutput $json

        $parameters = $json | ConvertTo-Hashtable
        $str = $parameters | Out-String
        LogOutput $str
        
        Invoke-AzureRmResourceAction -ResourceId "$LabId" -Action CreateEnvironment -Parameters $parameters -Force  | Out-Null
    } catch {
        Report-Error $_        
    }

}

function Extract-Tokens {
    <#
    .SYNOPSIS 
        Search content for TOKEN in format __TOKEN__

    .DESCRIPTION
        Search content for TOKEN in format __TOKEN__

    .PARAMETER Content
        Mandatory. Content to be used for token extractions

    .NOTES

    #>
    [CmdletBinding()]
    Param(
        [string] $Content
    )
    
    ([Regex]'__(?<Token>.*?)__').Matches($Content).Value.Trim('__')
}

# Substitute tokens in json
function Replace-Tokens {
    <#
    .SYNOPSIS 
        Replace the tokenized values in the content

    .DESCRIPTION
        Replace the tokenized values in the content

    .PARAMETER Content
        Mandatory. Content to be replaced in the JSON

    .PARAMETER Tokens
        Mandatory. Token values to be used for replacement

    .NOTES

    #>
    [CmdletBinding()]
    Param(
        [string] $Content,
        [hashtable] $Tokens
    )
    
    $Tokens.GetEnumerator() | % { $Content = $Content.Replace("__$($_.Key)__", "$($_.Value)") }
    
    return $Content
}
