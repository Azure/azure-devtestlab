[cmdletbinding()]
Param()
Import-Module $PSScriptRoot\..\Az.LabServices.psm1

$rgName     = 'Acme' + (Get-Random)
$rgLocation = 'West Europe'
$laName     = 'Workshops'

Describe 'Shared Gallery Management' {
    Context 'Pipeline Tests' {
        It 'Can attach a shared library' {

            if(-not (Get-AzResourceGroup -ResourceGroupName $rgName -EA SilentlyContinue)) {
                New-AzResourceGroup -ResourceGroupName $rgName -Location $rgLocation | Out-null
                Write-Verbose "$rgname resource group didn't exist. Created it."
            }
            
            $la  = New-AzLabAccount -ResourceGroupName $rgName -LabAccountName $laName
            Write-Verbose "$laName lab account created or found."
            
            $sg = Get-AzResource -resourceId "/subscriptions/39df6a21-006d-4800-a958-2280925030cb/resourceGroups/SharedImageGalleryRG/providers/Microsoft.Compute/galleries/EnterpriseSharedImages"
            $sg | Should -Not -Be $null

            $acsg = $la | New-AzLabAccountSharedGallery -SharedGallery $sg
            $acsg | Should -Not -Be $null

            $imgs = $la | Get-AzLabAccountSharedImage
            $img = $imgs[0]
            $img | Should -Not -Be $null

            # Cleanup
            Remove-AzResourceGroup -ResourceGroupName $rgName -Force
                        
        }
    }
}
