[cmdletbinding()]
Param()
Import-Module $PSScriptRoot\..\Az.LabServices.psm1

. $PSScriptRoot\Utils.ps1

$la = Get-FastLabAccount
$sg = Get-AzResource -resourceId "/subscriptions/39df6a21-006d-4800-a958-2280925030cb/resourceGroups/SharedImageGalleryRG/providers/Microsoft.Compute/galleries/EnterpriseSharedImages"

Describe 'Shared Gallery Management' {
    It 'Can attach a shared library' {
            
        # to run locally uncomment the line below and comment the next one
        #$sg = Get-AzResource -resourceId "/subscriptions/d5e481ac-7346-47dc-9557-f405e1b3dcb0/resourceGroups/myGalleryRG/providers/Microsoft.Compute/galleries/myGallery"
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
