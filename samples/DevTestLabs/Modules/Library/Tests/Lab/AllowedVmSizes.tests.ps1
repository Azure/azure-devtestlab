Import-Module $PSScriptRoot\..\..\Az.DevTestLabs2.psm1

$lab = @(
    [pscustomobject]@{Name=('DtlLibrary-LabPolicy-' + (Get-Random)); ResourceGroupName=('DtlLibrary-LabPolicyRg-' + (Get-Random)); Location='westus'}
)

Describe  'Get and Set Allowed VM Sizes Policy' {

    Context 'Pipeline Tests' {

        It 'Create the starting resources' {

            # Create the resource group, using a little property projection
            $lab | Select-Object -Property @{N='Name'; E={$_.ResourceGroupName}}, Location | New-AzureRmResourceGroup -Force | Out-Null

            # Create the lab
            $lab | New-AzDtlLab
        }

        It 'Able to Get and Set the VM Size policy' {
            # Get the policy succeeds, even if it's disabled initially
            ($lab | Get-AzDtlLabAllowedVmSizePolicy).Status | Should -Be "Disabled"

            # Set the policy
            $lab | Set-AzDtlLabAllowedVmSizePolicy -AllowedVmSizes "Standard_DS2_v2", "Standard_D3_v2"

            # Get the policy, confirm we have 2 now
            $sizePolicy = $lab | Get-AzDtlLabAllowedVmSizePolicy
            $sizePolicy.Status | Should -Be "Enabled"
            $sizePolicy.AllowedSizes.Count | Should -Be 2

        }

        It 'Able to Merge and Overwrite the VM Size policy' {

            # Add an additional size into the list
            $lab | Set-AzDtlLabAllowedVmSizePolicy -AllowedVmSizes "Standard_DS4_v2"

            # Should have 3 sizes in the list now
            ($lab | Get-AzDtlLabAllowedVmSizePolicy).AllowedSizes.Count | Should -Be 3

            # Overwrite the sizes with this single one
            $lab | Set-AzDtlLabAllowedVmSizePolicy -AllowedVmSizes "Standard_DS4_v2" -Overwrite

            # Should have 3 sizes in the list now
            ($lab | Get-AzDtlLabAllowedVmSizePolicy).AllowedSizes.Count | Should -Be 1
            
        }

        It 'Cleanup of resources' {

            # Remove Labs using the Lab Object returned from 'get' commandlet
            $lab | Get-AzDtlLab | Remove-AzDtlLab

            # Check that the labs are gone
            ($lab | Get-AzDtlLab -ErrorAction SilentlyContinue).Count | Should -Be 0
            
            # Clean up the resource groups since we don't need them
            $lab | Select-Object -Property @{N='Name'; E={$_.ResourceGroupName}}, Location | Remove-AzureRmResourceGroup -Force | Out-Null

        }
    }
}

