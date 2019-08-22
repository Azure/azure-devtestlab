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

# Here the test is made multi-thread safe by making sure to examine and delete just the objects that were created inside the test
# The worst that can happen is that it crashes after having created objects without deleting them, leaving garbage inside the common lab
# But that doesn't impede the subsequent tests to run fine as they create their own objects,
# but we might want to do a periodic clean up (nightly?) not to waste resources
Describe 'Schedule Management' {
    It 'Can create a schedule, get it and delete it' {
        $created = $schedules | ForEach-Object { $_ | New-AzLabSchedule -Lab $lab }
        Write-Verbose "Added all schedules."

        $foundNames = $lab | Get-AzLabSchedule | Select-Object -ExpandProperty Name

        $created | ForEach-Object {$_.Name | Should -BeIn $foundNames}

        $created | Should -Not -BeNullOrEmpty
        $created | Remove-AzLabSchedule
        
        $foundNames = $lab | Get-AzLabSchedule | Select-Object -ExpandProperty Name
        $created | ForEach-Object {$_.Name | Should -Not -BeIn $foundNames}       
    }
}
