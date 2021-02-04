[cmdletbinding()]
Param()
Import-Module $PSScriptRoot\..\Az.LabServices.psm1 -Force

#. $PSScriptRoot\Utils.ps1
Import-Module $PSScriptRoot\Utils.psm1 -Force
Write-Verbose "Loading Utils.psm1"

Describe 'Lab Account' {
        BeforeAll {
            $laName = "Temp$(Get-Random)"
        }

        It 'Can create a Lab Account' {
            
            $la = Get-FastResourceGroup 
            $script:rgName = $la.ResourceGroupName
            
            $la  = New-AzLabAccount -ResourceGroupName $script:rgName -LabAccountName $laName
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

            $la = Get-AzLabAccount -ResourceGroupName $script:rgName -LabAccountName $laName
            $la | Remove-AzLabAccount
        }
}
