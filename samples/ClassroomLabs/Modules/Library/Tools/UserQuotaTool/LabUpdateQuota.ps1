[CmdletBinding()]
param(
    [parameter(Mandatory = $true, ValueFromPipelineByPropertyName = $true)]
    [string]
    $CsvConfigFile
)

Import-Module ..\Az.LabServices.psm1 -Force
Import-Module '../../Az.LabServices.psm1' -Force
Import-Module './Quota.psm1' -Force

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$init = {
    function Update-AzLabSingleQuota {
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

            [parameter(Mandatory = $true, ValueFromPipelineByPropertyName = $true)]
            [ValidateNotNullOrEmpty()]
            $QuotaExtension
        )

        Write-Host "Start updating users quota for $LabName"

        $la = Get-AzLabAccount -ResourceGroupName $ResourceGroupName -LabAccountName $LabAccountName

        $lab = $la | Get-AzLab -LabName $LabName

        $users = $lab | Get-AzLabUser 
        $currentQuota = Get-Hours($lab.properties.usageQuota)

        foreach ($user in $users) {
   
            $totalUsage = Get-Hours($user.Properties.totalUsage)
    
            $currentHours = ($currentQuota) - $totalUsage
            $AddHours = $QuotaExtension - $currentHours
            if ($AddHours -gt 0) {
                Add-AzLabStudentUsage -Lab $lab -Email $user.properties.email -AdditionalUsage $AddHours
            }
            
        }
    
        Write-Host "$Lab students usage updated."

    }
}

  
function Update-AzLabMultiple {
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
        Import-Module './Quota.psm1' -Force
        # Really?? It got to be the lines below? Doing a ForEach doesn't work ...
        $input.movenext() | Out-Null
        $obj = $input.current[0]
        Write-Verbose "object inside the newazmultiple block $obj"
        $obj | Update-AzLabSingleQuota
    }

    Write-Host "Starting updating of all students for all labs in parallel. Can take a while."

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

$labs = Import-Csv -Path $CsvConfigFile

Write-Verbose ($labs | Format-Table | Out-String)

Write-Verbose ($labs | ConvertTo-Json -Depth 10 | Out-String)

Update-AzLabMultiple -ConfigObject $labs