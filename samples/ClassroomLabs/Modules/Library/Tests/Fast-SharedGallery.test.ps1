[cmdletbinding()]
Param()
Import-Module $PSScriptRoot\..\Az.LabServices.psm1

. $PSScriptRoot\Utils.ps1

$la = Get-FastLabAccount -Random
$sg = Get-FastGallery

Describe 'Shared Gallery Management' {
    It 'Can attach/detach a shared library' {
            
        $sg | Should -Not -Be $null
        $la | Should -Not -Be $null

        $acsg = $la | New-AzLabAccountSharedGallery -SharedGallery $sg
        $acsg | Should -Not -Be $null

        $imgs = $la | Get-AzLabAccountSharedImage
        $imgs | Should -Not -BeNullOrEmpty

        $la | Remove-AzLabAccountSharedGallery -SharedGalleryName $sg.Name
        $la | Remove-AzLabAccount
    }    
}
