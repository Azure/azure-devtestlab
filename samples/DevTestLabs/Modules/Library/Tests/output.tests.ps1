Import-Module $PSScriptRoot\..\Az.DevTestLabs2.psm1

$VerbosePreference="Continue"

Describe  'Test Suite' {

    Context 'Test' {

        It 'Success with write output' {
            Write-Output "Write-Output some output text"
            1 | Should -Be 1

        }

        It 'Success' {
            Write-Host "Write Host"
        }

        It 'write verbose' {
            Write-Verbose "Write-Verbose some text"
        }

        It 'Get Labs' {
            $labs = Dtl-GetLab
            $labs | Format-Table | Out-String | Write-Verbose
            Write-Verbose "Verbose Preference:  $VerbosePreference"

        }

    }
}

