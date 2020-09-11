function Get-Hours {
    [CmdletBinding()]
    param(
        [parameter(Mandatory = $true, ValueFromPipeline = $true)]
        [string]
        $RawTimeSpan
    )

    if($RawTimeSpan.Contains("D")) 
                {
                    $day = $RawTimeSpan.TrimStart("PT").Split("D")[0]
                    $rest = $RawTimeSpan.TrimStart("PT").Split("D")[1]
                } 
            else 
                {
                    $day = 0
                    $rest = $RawTimeSpan.TrimStart("PT")
                }

            if ($rest.Contains("H")) {
                $hour = $rest.Split("H")[0]
            }
            else {
                $hour = 0
            }

             return ($day * 24) + $hour
}


function Update-AzLabSingle {
    [CmdletBinding()]
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute("PSAvoidUsingPlainTextForPassword", "", Scope = "Function")]
    param(
        [parameter(Mandatory = $true, ValueFromPipelineByPropertyName = $true)]
        [ValidateNotNullOrEmpty()]
        [object]
        $Lab
    )

    Write-Host "Start update of $($Lab.Name)"

    #$la = Get-AzLabAccount -ResourceGroupName $Lab.ResourceGroupName -LabAccountName $Lab.LabAccountName

    #$lab = $la | Get-AzLab -LabName $Lab.LabName

    $users = $lab | Get-AzLabUser 

    #$RawQuota = $lab.properties.usageQuota
    $currentQuota = Get-Hours($lab.properties.usageQuota)

    foreach ($user in $users) {
        
        #$RawTotalUsage = $user.Properties.totalUsage
        #$RawAdditionalUsage = $user.Properties.additionalUsageQuota
        
        #$test = "PT2D4H3M.234"

        $totalUsage = Get-Hours($user.Properties.totalUsage)
        if ($user.Properties.additionalUsageQuota) {
            $currentAddUsage = Get-Hours($user.Properties.additionalUsageQuota)
        }
        else {
            $currentAddUsage = 0
        }
        

        $currentHours = ($currentQuota + $currentAddUsage) - $totalUsage
        $AddHours = 8 - $currentHours
        if ($AddHours -gt 0) {
            Add-AzLabStudentUsage -Lab $lab -Email $user.properties.email -AdditionalUsage $AddHours
        }
        
    }

    Write-Host "$Lab students usage updated."

}

Export-ModuleMember -Function   Get-Hours,
                                Update-AzLabSingle