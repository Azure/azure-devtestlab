[cmdletbinding()]
Param()
Import-Module $PSScriptRoot\..\Az.LabServices.psm1

. $PSScriptRoot\Utils.ps1


# Here the test is made multi-thread safe by making sure to examine and delete just the objects that were created inside the test
# The worst that can happen is that it crashes after having created objects without deleting them, leaving garbage inside the common lab
# But that doesn't impede the subsequent tests to run fine as they create their own objects,
# but we might want to do a periodic clean up (nightly?) not to waste resources
Describe 'Schedule' {

    BeforeAll {
        $today      = (Get-Date).ToString()
        $tomorrow   = (Get-Date).AddDays(1)
        $end        = (Get-Date).AddMonths(4).ToString()
    
        $script:lab = Get-FastLab
    
        $script:schedules = @(
            [PSCustomObject]@{Frequency = 'Weekly'; FromDate = $today; ToDate = $end; StartTime = '10:00'; EndTime = '11:00'; Notes = 'Theory' }
            [PSCustomObject]@{Frequency = 'Weekly'; FromDate = $tomorrow; ToDate = $end; StartTime = '11:00'; EndTime = '12:00'; Notes = 'Practice' }
        )
    }
    
    It 'Can create and retrieve schedules' {
        $script:created = $script:schedules | ForEach-Object { $_ | New-AzLabSchedule -Lab $script:lab }
        $foundNames = $script:lab | Get-AzLabSchedule | Select-Object -ExpandProperty Name
        $script:created | ForEach-Object {$_.Name | Should -BeIn $foundNames}
    }

    It 'can remove schedules' {
        $script:created | Should -Not -BeNullOrEmpty
        $script:created | Remove-AzLabSchedule
        
        $foundNames = $script:lab | Get-AzLabSchedule | Select-Object -ExpandProperty Name
        $script:created | ForEach-Object {$_.Name | Should -Not -BeIn $foundNames}       
    }
}
