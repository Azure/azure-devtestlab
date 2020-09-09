[cmdletbinding()]
Param()

Import-Module $PSScriptRoot\..\Az.DevTestLabs2.psm1 -Verbose:$false

$lab = @(
    [pscustomobject]@{Name=('DtlLibrary-LabSIGImg-' + (Get-Random)); ResourceGroupName=('DtlLibrary-LabSIGImgRg-' + (Get-Random)); Location='westus'}
)

# We are using an existing shared image gallery for this test, not ideal (external dependency) but takes to long to build it up and tear down every time
$SharedImageGalleryId = "/subscriptions/39df6a21-006d-4800-a958-2280925030cb/resourceGroups/SharedImageGalleryRG/providers/Microsoft.Compute/galleries/EnterpriseSharedImages"

Describe  'Get and Set SharedImageGalleryImages' {

    Context 'Pipeline Tests' {

        It 'Create the starting resources' {

            # Create the resource group, using a little property projection
            $lab | Select-Object -Property @{N='Name'; E={$_.ResourceGroupName}}, Location | New-AzureRmResourceGroup -Force | Out-Null

            # Create the lab
            $createdLab = $lab | New-AzDtlLab

            $createdLab | Should -Not -Be $null
            $createdLab | Out-String | Write-Verbose

            # Add the Shared Image Gallery
            $lab | Set-AzDtlLabSharedImageGallery -Name "EnterpriseImages" -ResourceId $SharedImageGalleryId

            # Confirm SIG set correctly
            $SIG = $lab | Get-AzDtlLabSharedImageGallery | Should -Not -Be $null

        }

        It 'Can set individual images as enabled or disabled' {

            Write-Verbose 'Getting the SIG with images'
            $SIG = $lab | Get-AzDtlLabSharedImageGallery -IncludeImages
            $SIG.Images | Should -Not -Be $null

            # At this point - we've got the images!  Let's pick the first Windows one and set it to disabled
            $image = $SIG.Images | Where-Object {$_.OsType -eq "Windows"} | Select-Object -First 1
            $SIG | Set-AzDtlLabSharedImageGalleryImages -ImageName $image.definitionName -OsType $image.osType -ImageType $image.imageType -Enabled $false
            
            # Get the images, confirm it was set the right way
            $sigImageResult = ($SIG | Get-AzDtlLabSharedImageGalleryImages | Where-Object {$_.OsType -eq "Windows"} | Select-Object -First 1).enableState
            $sigImageResult | Should -Be "Disabled"
            
            # Set again, to enabled
            $SIG = $lab | Get-AzDtlLabSharedImageGallery -IncludeImages
            $SIG | Set-AzDtlLabSharedImageGalleryImages -ImageName $image.definitionName -OsType $image.osType -ImageType $image.imageType -Enabled $true
            
            # Get the images, confirm it was set the right way
            $sigImageResult = ($SIG | Get-AzDtlLabSharedImageGalleryImages | Where-Object {$_.OsType -eq "Windows"} | Select-Object -First 1).enableState
            $sigImageResult | Should -Be "Enabled"

        }

        It 'Can update all the images as enabled or disabled together' {

            Write-Verbose 'Getting the SIG with images'
            $SIG = $lab | Get-AzDtlLabSharedImageGallery -IncludeImages

            $SIG.Images | Format-Table | Out-String | Write-Verbose
            Write-Verbose "Images Count: $($SIG.Images.Count)"

            $SIG.Images | ForEach-Object {
                    # Set them all to disabled
                    $_.enableState = "Disabled"
                 }

            $SIG | Set-AzDtlLabSharedImageGalleryImages

            # Confirm they're all set to disabled
            $SIG | Get-AzDtlLabSharedImageGalleryImages | ForEach-Object {
                $_.enableState | Should -Be "Disabled"
            }

            # Set them all back to enabled
            $SIG.Images | ForEach-Object {
                    # Set them all to enabled
                    $_.enableState = "Enabled"
                 }

            $SIG | Set-AzDtlLabSharedImageGalleryImages

            # Confirm they're all set to enabled
            $SIG | Get-AzDtlLabSharedImageGalleryImages | ForEach-Object {
                $_.enableState | Should -Be "Enabled"
            }
        }

        It 'Clean up resources' {
        
            # Remove Labs using the Lab Object returned from 'get' commandlet
            $lab | Get-AzDtlLab | Remove-AzDtlLab
           
            # Clean up the resource groups since we don't need them
            $lab | Select-Object -Property @{N='Name'; E={$_.ResourceGroupName}}, Location | Remove-AzureRmResourceGroup -Force | Out-Null

        }
    }
}
