[CmdletBinding()]
param(
    [parameter(Mandatory = $true, ValueFromPipelineByPropertyName = $true)]
    [string]
    $CsvConfigFile
)

Import-Module '../../Az.LabServices.psm1' -Force

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$init = {
    function Set-Users-AzLabSingle {
        [CmdletBinding()]
        [Diagnostics.CodeAnalysis.SuppressMessageAttribute("PSAvoidUsingPlainTextForPassword", "", Scope = "Function")]
        param(
            [parameter(Mandatory = $true, ValueFromPipelineByPropertyName = $true)]
            [ValidateNotNullOrEmpty()]
            $ResourceGroupName,

            [parameter(Mandatory = $true, ValueFromPipelineByPropertyName = $true)]
            [ValidateNotNullOrEmpty()]
            $LabAccountName,

            [parameter(Mandatory = $true, ValueFromPipelineByPropertyName = $true)]
            [ValidateNotNullOrEmpty()]
            $LabName,

            [parameter(Mandatory = $false, ValueFromPipelineByPropertyName = $true)]
            [string[]]
            $AddEmails,

            [parameter(Mandatory = $false, ValueFromPipelineByPropertyName = $true)]
            [string[]]
            $RemoveEmails,

            [parameter(Mandatory = $false, ValueFromPipelineByPropertyName = $true)]
            [string]
            $Invitation
        )

        Write-Host "Start adding users to $LabName"

        $la = Get-AzLabAccount -ResourceGroupName $ResourceGroupName -LabAccountName $LabAccountName

        $lab = $la | Get-AzLab -LabName $LabName

        #Section to send out invitation emails 
        if ($AddEmails) {
            $lab = $lab | Add-AzLabUser -Emails $AddEmails
            Write-Host "Added users $AddEmails"
            if ($Invitation) {
                $users = $lab | Get-AzLabUser
                $users | ForEach-Object { $lab | Send-AzLabUserInvitationEmail -User $_ -InvitationText $invitation } | Out-Null
                Write-Host "Sent Invitation: $AddEmails."
            }
        }
        if ($RemoveEmails) {
            #Todo Review for improvements.
            $usersToRemove = $RemoveEmails | ForEach-Object {$lab | Get-AzLabUser -Email $_}
            $usersToRemove | ForEach-Object { Remove-AzLabUser -Lab $lab -User $_}            
        }
    }
}
  
function Set-Users-AzLabMultiple {
    [CmdletBinding()]
    param(
        [parameter(Mandatory = $true, ValueFromPipeline = $true)]
        [psobject[]]
        $ConfigObject
    )

    $block = {
        param($path)

        Set-StrictMode -Version Latest
        $ErrorActionPreference = 'Stop'
        
        Import-Module '../../Az.LabServices.psm1' -Force
        # Really?? It got to be the lines below? Doing a ForEach doesn't work ...
        $input.movenext() | Out-Null
        $obj = $input.current[0]
        Write-Verbose "object inside the newazmultiple block $obj"
        $obj | Set-Users-AzLabSingle
    }

    Write-Host "Starting adding users for all labs in parallel. Can take a while."

    $jobs = $ConfigObject | ForEach-Object {
        Write-Verbose "From config: $_"
        Start-ThreadJob  -InitializationScript $init -ScriptBlock $block -ArgumentList $PSScriptRoot -InputObject $_ -Name $_.LabName -ThrottleLimit 5
    }

    while (($jobs | Measure-Object).Count -gt 0) {
        $completedJobs = $jobs | Where-Object {($_.State -ieq "Completed") -or ($_.State -ieq "Failed")}
        if (($completedJobs | Measure-Object).Count -gt 0) {
            # Write output for completed jobs, but one by one so output doesn't bleed 
            # together, also use "Continue" so we write the error but don't end the outer script
            $completedJobs | ForEach-Object {
                $_ | Receive-Job -ErrorAction Continue
            }
            # Trim off the completed jobs from our list of jobs
            $jobs = $jobs | Where-Object {$_.Id -notin $completedJobs.Id}
            # Remove the completed jobs from memory
            $completedJobs | Remove-Job
        }
        # Wait for 60 sec before checking job status again
        Start-Sleep -Seconds 60
    }

}

function Import-Emails {
    param($emails)

    $file = "./$emails.csv"

    $usersArray = @()
    $users = Import-Csv $file
    $users | Foreach-Object {
        $usersArray += $_.Students
    }
    return $usersArray
}

$labs = Import-Csv -Path $CsvConfigFile

Write-Verbose ($labs | Format-Table | Out-String)

$labs | ForEach-Object {
    if ($_.AddEmails) {
        Write-Host "Adding Students for $($_.LabName)"
        $_.AddEmails = Import-Emails -emails $_.AddEmails
    }
    if ($_.RemoveEmails) {
        Write-Host "Remove Students for $($_.LabName)"        
        $_.RemoveEmails = Import-Emails -emails $_.RemoveEmails 
    }
}

Write-Verbose ($labs | ConvertTo-Json -Depth 10 | Out-String)

Set-Users-AzLabMultiple -ConfigObject $labs
