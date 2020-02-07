[cmdletbinding()]
Param()

Import-Module $PSScriptRoot\..\Az.DevTestLabs2.psm1 -Verbose:$false

$labs = @(
    [pscustomobject]@{Name=('DtlLibrary-LabPipeline-' + (Get-Random)); ResourceGroupName=('DtlLibrary-LabPipelineRg-' + (Get-Random)); Location='westus'},
    [pscustomobject]@{Name=('DtlLibrary-LabPipeline-' + (Get-Random)); ResourceGroupName=('DtlLibrary-LabPipelineRg-' + (Get-Random)); Location='eastus'}
)

Describe  'Lab Creation and Deletion' {

    Context 'Pipeline Tests' {

        It 'DevTest Labs can be created with pipeline' {

            # Create the resource groups, using a little property projection
            $labs | Select-Object -Property @{N='Name'; E={$_.ResourceGroupName}}, Location | New-AzureRmResourceGroup -Force | Out-Null

            # Create the labs
            $labs | New-AzDtlLab

            # Query Azure to get the created labs to make sure they really exist
            $createdLabs = $labs | Get-AzDtlLab

            # Check the number of labs created and that they were successful
            $createdLabs.Count | Should -Be 2

            foreach ($lab in $createdLabs) {
                $lab.Properties.provisioningState | Should -Be "Succeeded"
            }

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

