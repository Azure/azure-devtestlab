Import-Module $PSScriptRoot\..\..\Az.DevTestLabs2.psm1

$labs = @(
    [pscustomobject]@{Name='DTL-Library-Test1'; ResourceGroupName='DTL-Library-Test1rg'; Location='westus'},
    [pscustomobject]@{Name='DTL-Library-Test2'; ResourceGroupName='DTL-Library-Test2rg'; Location='eastus'}
)

Describe  'Lab Creation and Deletion' {

    Context 'Pipeline Tests' {

        It 'DevTest Labs can be created with pipeline' {

            # Create the resource groups, using a little property projection
            $labs | Select-Object -Property @{N='Name'; E={$_.ResourceGroupName}}, Location | New-AzureRmResourceGroup -Force | Out-Null

            # Create the labs
            $createdLabs = $labs | New-AzDtlLab

            # Check the number of labs created
            $createdLabs.Count | Should be 2

            # Check that the labs really exist
            $createdLabs | Get-AzDtlLab | Should not be $null

        }

        It 'DevTest Labs can be deleted with pipeline' {

            # Remove Labs using the Lab Object returned from 'get' commandlet
            $labs | Get-AzDtlLab | Remove-AzDtlLab

            # Check that the labs are gone
            ($labs | Get-AzDtlLab -ErrorAction SilentlyContinue).Count | Should be 0
        }

        It 'Cleanup of resources' {

            # Clean up the resource groups since we don't need them
            $labs | Select-Object -Property @{N='Name'; E={$_.ResourceGroupName}}, Location | Remove-AzureRmResourceGroup -Force | Out-Null

        }
    }
}

