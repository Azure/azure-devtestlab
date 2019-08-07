Import-Module $PSScriptRoot\..\Az.LabServices.psm1
$VerbosePreference="Continue"

$today      = (Get-Date).ToString()
$tomorrow   = (Get-Date).AddDays(1)
$end        = (Get-Date).AddMonths(4).ToString()

$rgName     = 'Acme' + (Get-Random)
$rgLocation = 'West Europe'
$labName    = 'Advancing Differenciation'
$laName     = 'Workshops'
$imgName    = 'CentOS-Based*'
$maxUsers   = 2
$usageQuota = 30
$usageAMode = 'Restricted'
$shPsswd    = $false
$size       = 'Medium'
$title      = 'Advancing Differentiation Workshop'
$descr      = 'Bringing it to the 21st Century'
$userName   = 'test0000'
$password   = 'Test00000000'
$linuxRdp   = $true

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
