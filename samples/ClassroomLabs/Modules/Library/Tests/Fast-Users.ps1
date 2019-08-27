[cmdletbinding()]
Param()
Import-Module $PSScriptRoot\..\Az.LabServices.psm1

. $PSScriptRoot\Utils.ps1


# Here the test is made multi-thread safe by making sure to examine and delete just the objects that were created inside the test
# The worst that can happen is that it crashes after having created objects without deleting them, leaving garbage inside the common lab
# But that doesn't impede the subsequent tests to run fine as they create their own objects,
# but we might want to do a periodic clean up (nightly?) not to waste resources
Describe 'Users' {

    BeforeAll {
        $script:lab = Get-FastLab
        [string[]]$script:userNames = @(('test' + (Get-Random) + '@test.com'), ('test' + (Get-Random) + '@test.com'))
    }
    
    It 'Can add users to lab and get them' {
        $lab | Add-AzLabUser -Email $script:userNames
        $foundEmails = $script:lab | Get-AzLabUser | Select-Object -ExpandProperty Properties | Select-Object -ExpandProperty Email
        $script:userNames | ForEach-Object {$_ | Should -BeIn $foundEmails}
    }

    It 'Can remove users' {
        $foundUsers = $script:lab | Get-AzLabUser | Where-Object { $script:userNames.Contains($_.properties.Email) }
        $foundUsers | ForEach-Object {$script:lab | Remove-AzLabUser -User $_}
        $foundUsers = $script:lab | Get-AzLabUser
        $foundUsers | ForEach-Object {$_.properties.Email | Should -Not -BeIn $foundEmails}
    }
}
