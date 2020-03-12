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
    
    It 'Can start VM' {
        $script:vm | Should -Not -BeNullOrEmpty
        $script:vm | Start-AzLabVm

        $started = $script:lab | Get-AzLabVm -Status 'Running'
        $started | Should -Not -BeNullOrEmpty
        $matched = $started | Where-Object Name -eq $script:vm.Name
        $matched | Should -Not -BeNullOrEmpty
    }

    It 'Can stop VM' {
        $script:vm | Stop-AzLabVm
        $script:lab | Get-AzLabVm -Status 'Stopped' | Where-Object { $_.Name -eq $script:vm.Name} | Should -Not -BeNullOrEmpty
    }
}
