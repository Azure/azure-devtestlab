[cmdletbinding()]
Param()
Import-Module $PSScriptRoot\..\Az.LabServices.psm1

. $PSScriptRoot\Utils.ps1


Describe 'Shared Gallery' {

    BeforeAll {
        $script:la = Get-FastLabAccount -RandomName
        $script:sg = Get-FastGallery
    }

    AfterAll {
        $script:la | Remove-AzLabAccount
    }

    It 'Can attach/detach a shared library' {
        $script:sg | Should -Not -Be $null
        $script:la | Should -Not -Be $null

        $acsg = $script:la | New-AzLabAccountSharedGallery -SharedGallery $script:sg
        $acsg | Should -Not -Be $null
    }

    It 'Can retrieve images' {
        $imgs = $script:la | Get-AzLabAccountSharedImage
        $imgs | Should -Not -BeNullOrEmpty
    }

    It 'Can remove a gallery' {
        $script:la | Remove-AzLabAccountSharedGallery -SharedGalleryName $script:sg.Name
    }
}
