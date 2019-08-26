[cmdletbinding()]
Param()
Import-Module $PSScriptRoot\..\Az.LabServices.psm1

$rgName     = 'AzLabsLibrary'
$rgLocation = 'West Europe'
$laName     = 'Temp' + (Get-Random)

Describe 'Lab Account' {
        It 'Can create a Lab Account' {

            if(-not (Get-AzResourceGroup -ResourceGroupName $rgName -EA SilentlyContinue)) {
                New-AzResourceGroup -ResourceGroupName $rgName -Location $rgLocation | Out-null
                Write-Verbose "$rgname resource group didn't exist. Created it."
            }
            
            $la  = New-AzLabAccount -ResourceGroupName $rgName -LabAccountName $laName
            Write-Verbose "$laName lab account created or found."
            
            $la | Should -Not -BeNullOrEmpty
        }

        It 'Can query using wildcards' {
            Get-AzLabAccount -ResourceGroupName az*                                             | Should -Not -BeNullOrEmpty
            Get-AzLabAccount -ResourceGroupName azlabslibrary -LabAccountName Az*               | Should -Not -BeNullOrEmpty
            Get-AzLabAccount -ResourceGroupName az* -LabAccountName Az*                         | Should -Not -BeNullOrEmpty            
            Get-AzLabAccount -ResourceGroupName azlabslibrary -LabAccountName AzLabsLibrary-la  | Should -Not -BeNullOrEmpty           
        }

        It 'Can remove Lab Account' {

            $la = Get-AzLabAccount -ResourceGroupName $rgName -LabAccountName $laName
            $la | Remove-AzLabAccount
        }
}
