[cmdletbinding()]
Param()
Import-Module $PSScriptRoot\..\Az.LabServices.psm1

$rgName     = 'AzLabsLibrary'
$rgLocation = 'West Europe'
$laName     = 'Temp' + (Get-Random)

Describe 'Lab Account Crud' {
        It 'Can create a Lab Account' {

            if(-not (Get-AzResourceGroup -ResourceGroupName $rgName -EA SilentlyContinue)) {
                New-AzResourceGroup -ResourceGroupName $rgName -Location $rgLocation | Out-null
                Write-Verbose "$rgname resource group didn't exist. Created it."
            }
            
            $la  = New-AzLabAccount -ResourceGroupName $rgName -LabAccountName $laName
            Write-Verbose "$laName lab account created or found."
            
            $la | Should -Not -BeNullOrEmpty
        }

        It 'Can remove Lab Account' {

            $la = Get-AzLabAccount -ResourceGroupName $rgName -LabAccountName $laName
            $la | Remove-AzLabAccount
        }
}
