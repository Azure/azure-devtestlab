[cmdletbinding()]
Param()
Import-Module $PSScriptRoot\..\Az.LabServices.psm1
$VerbosePreference="Continue"

$rgName     = 'Acme' + (Get-Random)
$rgLocation = 'West Europe'
$laName     = 'Workshops'

Describe 'Shared Gallery Management' {
    Context 'Pipeline Tests' {
        It 'Can attach a shared library' {

            # Creat RG, Lab Account and lab if not existing
            if(-not (Get-AzResourceGroup -ResourceGroupName $rgName -EA SilentlyContinue)) {
                New-AzResourceGroup -ResourceGroupName $rgName -Location $rgLocation | Out-null
                Write-Verbose "$rgname resource group didn't exist. Created it."
            }
            
            $la  = New-AzLabAccount -ResourceGroupName $rgName -LabAccountName $laName
            Write-Verbose "$laName lab account created or found."
            
            $sg = Get-AzResource -resourceId "/subscriptions/39df6a21-006d-4800-a958-2280925030cb/resourceGroups/SharedImageGalleryRG/providers/Microsoft.Compute/galleries/EnterpriseSharedImages"
            $sg | Should -Not -Be $null

            $la = $la | New-AzLabAccountSharedGallery -SharedGallery $sg

            $imgs = $la | Get-AzLabAccountSharedImage
            $imgs.Count | Should -BeGreaterThan 0

            # Cleanup
            Remove-AzResourceGroup -ResourceGroupName $rgName -Force
                        
        }
    }
}
