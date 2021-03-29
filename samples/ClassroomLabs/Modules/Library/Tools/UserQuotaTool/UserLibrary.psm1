function Convert-UsageQuotaToHours {
    [CmdletBinding()]
    param(
        [parameter(Mandatory = $true, ValueFromPipeline = $true)]
        [string]
        $RawTimeSpan
    )

    $usage = [System.Xml.XmlConvert]::ToTimeSpan($RawTimeSpan)
    return [math]::Ceiling($usage.TotalHours)
}

function Update-AzLabUserQuotaBulk {
    [CmdletBinding()]
    param(
        [parameter(Mandatory = $true, HelpMessage = "Array containing one line for each lab to be updated.", ValueFromPipeline = $true)]
        [ValidateNotNullOrEmpty()]
        [psobject[]]
        $labs,

        [parameter(Mandatory = $true, HelpMessage = "Amount of unused quota hours that will be set for each user.", ValueFromPipelineByPropertyName = $true)]
        [string]
        $AdditionalHours,

        [parameter(Mandatory = $false, ValueFromPipelineByPropertyName = $true)]
        [int]
        $ThrottleLimit = 5
    )

    begin {
        # This patterns aggregates all the objects in the pipeline before performing an operation
        # i.e. executes lab creation in parallel instead of sequentially
        # This trick is to make it work both when the argument is passed as pipeline and as normal arg.
        # I came up with this. Maybe there is a better way.
        $aggregateLabs = @()
    }
    process {
        # If passed through pipeline, $labs is a single object, otherwise it is the whole array
        # It works because PS uses '+' to add objects or arrays to an array
        $aggregateLabs += $labs
    }
    end {
    
        $init = {
        }
        function Update-AzLabUserQuotaBulk-Job {
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
                Import-Module ../UserLibrary.psm1 -Force
                
                # Really?? It got to be the lines below? Doing a ForEach doesn't work ...
                $input.movenext() | Out-Null
                $obj = $input.current[0]
                Write-Verbose "object inside the Update-AzLabUserQuotaBulk-Job block $obj"
                
                $la = Get-AzLabAccount -ResourceGroupName $obj.ResourceGroupName -LabAccountName $obj.LabAccountName
                if (-not $la -or @($la).Count -ne 1) { Write-Error "Unable to find lab account $($obj.LabAccountName)."}

                $lab = Get-AzLab -LabAccount $la -LabName $obj.LabName
                if (-not $lab -or @($lab).Count -ne 1) { Write-Error "Unable to find lab $($obj.LabName)."}

                $users = Get-AzLabUser -Lab $lab -Email "*"

                $currentQuota = Convert-UsageQuotaToHours($lab.properties.usageQuota)
                foreach ($user in $users) {
                    $totalUsage = Convert-UsageQuotaToHours($user.Properties.totalUsage)
                    if ($user.Properties -contains "additionalUsageQuota") {
                        $currentAddUsage = Convert-UsageQuotaToHours($user.Properties.additionalUsageQuota)
                    }
                    else {
                        $currentAddUsage = 0
                    }
                    
                    # The available quota is the current Lab quota ($currentQuota) and the individual additional quota ($currentAddUsage)
                    #   subtracting the used quota ($totalUsage) returns the unused portion.  The goal is to have the unused portion equal
                    #   to the AdditionalHours.  Any unused existing quota is removed from the AdditionalHours and that is added to the users quota.
                    $currentHours = ($currentQuota + $currentAddUsage) - $totalUsage
                    $AddHours = $obj.AdditionalHours - $currentHours
                    if ($AddHours -gt 0) {
                        Set-AzLabUser -Lab $lab -User $user -AdditionalUsageQuota $AddHours | Out-Null
                    }
                }
            }

            $jobs = $ConfigObject | ForEach-Object {
                Write-Verbose "From config: $_"
                Start-ThreadJob  -InitializationScript $init -ScriptBlock $block -ArgumentList $PSScriptRoot -InputObject $_ -Name $_.LabName -ThrottleLimit $ThrottleLimit
            }

            while (($jobs | Measure-Object).Count -gt 0) {
                # If we have more jobs, wait for 60 sec before checking job status again
                Start-Sleep -Seconds 60

                $completedJobs = $jobs | Where-Object {($_.State -ieq "Completed") -or ($_.State -ieq "Failed")}
                if (($completedJobs | Measure-Object).Count -gt 0) {
                    # Write output for completed jobs, but one by one so output doesn't bleed 
                    # together, also use "Continue" so we write the error but don't end the outer script
                    $completedJobs | ForEach-Object {
                        # For each completed job we write the result back to the appropriate Config object, using the "name" field to coorelate
                        $_ | Receive-Job -ErrorAction Continue
                    }
                    # Trim off the completed jobs from our list of jobs
                    $jobs = $jobs | Where-Object {$_.Id -notin $completedJobs.Id}
                    # Remove the completed jobs from memory
                    $completedJobs | Remove-Job
                }
            }

            return $ConfigObject

        }

        $outerScriptstartTime = Get-Date
        Write-Host "Updating Student Quotas all student for all labs, starting at $outerScriptstartTime.  This can take a while." -ForegroundColor Green

        Update-AzLabUserQuotaBulk-Job -ConfigObject $aggregateLabs

        Write-Host "Completed updating Student Quota, total duration $(((Get-Date) - $outerScriptstartTime).TotalMinutes) minutes" -ForegroundColor Green

    }
}

Export-ModuleMember -Function   Convert-UsageQuotaToHours,
                                Update-AzLabUserQuotaBulk