[cmdletbinding()]
Param()
Import-Module $PSScriptRoot\..\Az.LabServices.psm1

. $PSScriptRoot\Utils.ps1

$today      = (Get-Date).ToString()
$tomorrow   = (Get-Date).AddDays(1)
$end        = (Get-Date).AddMonths(4).ToString()

$lab = Get-FastLab

$schedules = @(
    [PSCustomObject]@{Frequency = 'Weekly'; FromDate = $today; ToDate = $end; StartTime = '10:00'; EndTime = '11:00'; Notes = 'Theory' }
    [PSCustomObject]@{Frequency = 'Weekly'; FromDate = $tomorrow; ToDate = $end; StartTime = '11:00'; EndTime = '12:00'; Notes = 'Practice' }
)

Describe 'Schedule Management' {
    It 'Can create a schedule, get it and delete it' {
            
        # Manage leftovers from previous failed runs.
        $created = $lab | Get-AzLabSchedule
        if ($created) {
            $created | Remove-AzLabSchedule   
        }

        # Create Schedules
        $schedules | ForEach-Object { $_ | New-AzLabSchedule -Lab $lab } | Out-Null
        Write-Verbose "Added all schedules."

        # Get Schedules
        $created = $lab | Get-AzLabSchedule
        $created | Should -HaveCount $schedules.Count

    }

    It 'Can remove schedule' {

        $created = $lab | Get-AzLabSchedule
        $created | Should -HaveCount $schedules.Count
        $created | Remove-AzLabSchedule
        $existing = $lab | Get-AzLabSchedule
        $existing | Should -HaveCount 0                        
            
    }
}
