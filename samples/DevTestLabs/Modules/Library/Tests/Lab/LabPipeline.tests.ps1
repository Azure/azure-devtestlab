Import-Module $PSScriptRoot\..\..\Az.DevTestLabs2.psm1

$labs = @(
    [pscustomobject]@{Name=('DtlLibrary-Lab-' + (Get-Random)); ResourceGroupName=('DtlLibrary-LabRg-' + (Get-Random)); Location='westus'},
    [pscustomobject]@{Name=('DtlLibrary-Lab-' + (Get-Random)); ResourceGroupName=('DtlLibrary-LabRg-' + (Get-Random)); Location='eastus'}
)

Describe  'Lab Creation and Deletion' {

    Context 'Pipeline Tests' {

        It 'DevTest Labs can be created with pipeline' {

            # Create the resource groups, using a little property projection
            $labs | Select-Object -Property @{N='Name'; E={$_.ResourceGroupName}}, Location | New-AzureRmResourceGroup -Force | Out-Null

            # Create the labs
            $createdLabs = $labs | New-AzDtlLab

            # Check the number of labs created and that they were successful
            $createdLabs.Count | Should -Be 2
            foreach ($lab in $createdLabs) {
                $lab.Properties.provisioningState | Should -Be "Succeeded"
            }

            # Check that the labs really exist
            $createdLabs | Get-AzDtlLab | Should -Not -Be $null

        }

        It 'DevTest Labs can be deleted with pipeline' {

            # Remove Labs using the Lab Object returned from 'get' commandlet
            $labs | Get-AzDtlLab | Remove-AzDtlLab

            # Check that the labs are gone
            ($labs | Get-AzDtlLab -ErrorAction SilentlyContinue).Count | Should -Be 0
        }

        It 'Cleanup of resources' {

            # Clean up the resource groups since we don't need them
            $labs | Select-Object -Property @{N='Name'; E={$_.ResourceGroupName}}, Location | Remove-AzureRmResourceGroup -Force | Out-Null

        }
    }
}

