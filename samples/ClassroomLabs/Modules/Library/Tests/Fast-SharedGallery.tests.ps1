[cmdletbinding()]
Param()
Import-Module $PSScriptRoot\..\Az.LabServices.psm1

. $PSScriptRoot\Utils.ps1


# Get-AzGallery returns empty on github action VMs, but not on my machine.
# Disabling the test
# I use it from console. Disabling the test for now.
Describe 'Shared Gallery' {

    BeforeAll {
        $script:la = Get-FastLabAccount
        # $script:la = Get-FastLabAccount -RandomName
        # $script:sg = Get-FastGallery
    }

    AfterAll {
        # $script:la | Remove-AzLabAccount
    }

    It 'Can attach/detach a shared library' -Skip {
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
    It 'Can remove a gallery' -Skip {
        $script:la | Remove-AzLabAccountSharedGallery -SharedGalleryName $script:sg.Name
    }
}
