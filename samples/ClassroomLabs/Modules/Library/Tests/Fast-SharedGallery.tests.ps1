[cmdletbinding()]
Param()
Import-Module $PSScriptRoot\..\Az.LabServices.psm1 -Force

#. $PSScriptRoot\Utils.ps1
Import-Module $PSScriptRoot\Utils.psm1 -Force
Write-Verbose "Loading Utils.psm1"

Describe 'Shared Gallery' {

    BeforeAll {
        $script:la = Get-FastLabAccount
        # $script:la = Get-FastLabAccount -RandomName
        $script:sg = Get-FastGallery
    }

    AfterAll {
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

    # Also disabling this until I find solution for above.
    It 'Can remove a gallery' {
        $script:la | Remove-AzLabAccountSharedGallery -SharedGalleryName $script:sg.Name
    }
}
