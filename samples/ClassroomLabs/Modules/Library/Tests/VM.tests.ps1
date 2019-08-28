[cmdletbinding()]
Param()
Import-Module $PSScriptRoot\..\Az.LabServices.psm1

. $PSScriptRoot\Utils.ps1


Describe 'VMs' {

    BeforeAll {
        $script:lab = Get-FastLab -RandomName
        $script:vms = $script:lab | Get-AzLabVm
        $script:vm = $script:vms[0]
    }

    AfterAll {
        $script:lab | Remove-AzLab
    }
    
    It 'Can start VM' -Skip {
        $script:vm.Status | Should -Be 'Stopped'
        $script:vm | Start-AzLabVm
        $started = $script:lab | Get-AzLabVm -Status 'Running'
        $started.Count | Should -Be 1
        $started[0].Name | Should -Be $script:vm.Name
    }

    It 'Can stop VM' {
        $script:vm | Stop-AzLabVm
        $script:lab | Get-AzLabVm -Status 'Stopped' | Where-Object { $_.Name -eq $script:vm.Name} | Should -Not -BeNullOrEmpty
    }
}
