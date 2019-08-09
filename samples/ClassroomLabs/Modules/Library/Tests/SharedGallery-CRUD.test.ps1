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
            
            # to run locally uncomment the line below and comment the next one
            #$sg = Get-AzResource -resourceId "/subscriptions/d5e481ac-7346-47dc-9557-f405e1b3dcb0/resourceGroups/myGalleryRG/providers/Microsoft.Compute/galleries/myGallery"
            $sg = Get-AzResource -resourceId "/subscriptions/39df6a21-006d-4800-a958-2280925030cb/resourceGroups/SharedImageGalleryRG/providers/Microsoft.Compute/galleries/EnterpriseSharedImages"
            $sg | Should -Not -Be $null

            $acsg = $la | New-AzLabAccountSharedGallery -SharedGallery $sg
            $acsg | Should -Not -Be $null

            $imgs = $la | Get-AzLabAccountSharedImage
            $imgs.Count | Should -BeGreaterThan 0

            # Cleanup
            Remove-AzResourceGroup -ResourceGroupName $rgName -Force
                        
        }
    }
}
