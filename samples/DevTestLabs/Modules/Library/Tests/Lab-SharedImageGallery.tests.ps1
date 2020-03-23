[cmdletbinding()]
Param()

Import-Module $PSScriptRoot\..\Az.DevTestLabs2.psm1 -Verbose:$false

$lab = @(
    [pscustomobject]@{Name=('DtlLibrary-LabSIG-' + (Get-Random)); ResourceGroupName=('DtlLibrary-LabSIGRg-' + (Get-Random)); Location='westus'}
)

# We are using an existing shared image gallery for this test, not ideal (external dependency) but takes to long to build it up and tear down every time
$SharedImageGalleryId = "/subscriptions/39df6a21-006d-4800-a958-2280925030cb/resourceGroups/SharedImageGalleryRG/providers/Microsoft.Compute/galleries/EnterpriseSharedImages"

Describe  'Get and Set SharedImageGallery' {

    Context 'Pipeline Tests' {

        It 'Create the starting resources' {

            # Create the resource group, using a little property projection
            $lab | Select-Object -Property @{N='Name'; E={$_.ResourceGroupName}}, Location | New-AzureRmResourceGroup -Force | Out-Null

            # Create the lab
            $lab | New-AzDtlLab

            # WORKAROUND for 1082372
            $lab | ForEach-Object {
               Set-AzResource -ResourceGroupName $_.ResourceGroupName -ResourceType 'Microsoft.DevTestLab/labs/users' -Name "$($_.Name)/@me" -ApiVersion 2018-10-15-preview -Force
            }

            $result | Out-String | Write-Verbose
        }

        It 'Get and Set for Shared Image Gallery' {

            # Ensure for a fresh lab, I get null when trying to get the SIG
            $lab | Get-AzDtlLabSharedImageGallery | Should -Be $null
            
            # Set the SIG - default is to allow all images
            $lab | Set-AzDtlLabSharedImageGallery -Name "EnterpriseImages" -ResourceId $SharedImageGalleryId | Should -Not -Be $null

            # Confirm we have the SIG set now
            $lab | Get-AzDtlLabSharedImageGallery | Should -Not -Be $null

        }

        It 'Verify Remove and overwrite-Set for the Shared Image Gallery' {

            # At this point - already have a SIG set - let's remove it
            $SIG = $lab | Get-AzDtlLabSharedImageGallery
            Write-Verbose "Existing shared Image Gallery Resource:"
            $SIG | Out-String | Write-Verbose

            $SIG | Remove-AzDtlLabSharedImageGallery

            # Try to remove it again - shouldn't error out
            $SIG | Remove-AzDtlLabSharedImageGallery

            Write-Verbose "Set the SIG resource again..."
            # Set the SIG again
            $lab | Set-AzDtlLabSharedImageGallery -Name "EnterpriseImages" -ResourceId $SharedImageGalleryId -AllowAllImages $false | Should -Not -Be $null
            
            Write-Verbose "Update existing SIG resource with allow images = true"
            # Set the SIG to update the existing SIG with allow images = true
            $lab | Set-AzDtlLabSharedImageGallery -Name "EnterpriseImages" -ResourceId $SharedImageGalleryId -AllowAllImages $true | Should -Not -Be $null

        }

        It 'Clean up resources' {
        
            # Remove Labs using the Lab Object returned from 'get' commandlet
            $lab | Get-AzDtlLab | Remove-AzDtlLab
           
            # Clean up the resource groups since we don't need them
            $lab | Select-Object -Property @{N='Name'; E={$_.ResourceGroupName}}, Location | Remove-AzureRmResourceGroup -Force | Out-Null

        }
    }
}