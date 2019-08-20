[cmdletbinding()]
Param()
Import-Module $PSScriptRoot\..\Az.LabServices.psm1

. $PSScriptRoot\Utils.ps1

$la = Get-FastLabAccount
$sg = Get-FastGallery

Describe 'Shared Gallery Management' {
    It 'Can attach a shared library' {
            
        $sg | Should -Not -Be $null

        $acsg = $la | New-AzLabAccountSharedGallery -SharedGallery $sg
        $acsg | Should -Not -Be $null

        $imgs = $la | Get-AzLabAccountSharedImage
        $imgs.Count | Should -BeGreaterThan 0

    }

    It 'Can detach a shared library' {
        $la | Remove-AzLabAccountSharedGallery -SharedGalleryName $sg.Name  
    }    
}
