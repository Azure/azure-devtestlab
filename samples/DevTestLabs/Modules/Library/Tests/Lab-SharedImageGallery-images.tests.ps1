[cmdletbinding()]
Param()

Import-Module $PSScriptRoot\..\Az.DevTestLabs2.psm1 -Verbose:$false

$lab = @(
    [pscustomobject]@{Name=('DtlLibrary-LabSIGImg-' + (Get-Random)); ResourceGroupName=('DtlLibrary-LabSIGImgRg-' + (Get-Random)); Location='westus'}
)

# We are using an existing shared image gallery for this test, not ideal (external dependency) but takes to long to build it up and tear down every time
$SharedImageGalleryId = "/subscriptions/39df6a21-006d-4800-a958-2280925030cb/resourceGroups/SharedImageGalleryRG/providers/Microsoft.Compute/galleries/EnterpriseSharedImages"

function GetSharedImageGalleryWithDelay {
    Param ($lab)
 
    $SIG = $lab | Get-AzDtlLabSharedImageGallery -IncludeImages

    $count = 10
    while ($SIG.Images -eq $null -and $count -gt 0) {
        # delay for a little bit and try again
        Start-Sleep -Seconds 60
        $count --
        Write-Verbose "Getting the SIG with images again - count: $count"
        $SIG = $lab | Get-AzDtlLabSharedImageGallery -IncludeImages
    }

    return $SIG
}

function SetSharedImageGalleryWithDelay {
    Param ($lab, $SharedImageGalleryId)

    $lab | Set-AzDtlLabSharedImageGallery -Name "EnterpriseImages" -ResourceId $SharedImageGalleryId

    $SIG = $lab | Get-AzDtlLabSharedImageGallery
    $count = 10

    while ($SIG -eq $null -and $count -gt 0) {
        # Sleep for 1 min before reapplying shared image gallery
        Start-Sleep -Seconds 60
        $count --
        Write-Verbose "Adding SIG to the lab again - count: $count"
        $lab | Set-AzDtlLabSharedImageGallery -Name "EnterpriseImages" -ResourceId $SharedImageGalleryId | Out-Null
        $SIG = $lab | Get-AzDtlLabSharedImageGallery
    }
}

function GetSharedImageGalleryImagesWithDelay {
    Param ($SIG)
 
    $images = $SIG | Get-AzDtlLabSharedImageGalleryImages

    $count = 10
    while (($images -eq $null -or `
            $images.Count -eq 0 -or `
            ($images | Select -First 1).enableState -eq $null) -and $count -gt 0) {
        # delay for a little bit and try again
        Start-Sleep -Seconds 60
        $count --
        Write-Verbose "Getting the SIG images again - count: $count"
        $images = $SIG | Get-AzDtlLabSharedImageGalleryImages
    }

    return $images
}


Describe  'Get and Set SharedImageGalleryImages' {

    Context 'Pipeline Tests' {

        It 'Create the starting resources' {

            # Create the resource group, using a little property projection
            $lab | Select-Object -Property @{N='Name'; E={$_.ResourceGroupName}}, Location | New-AzureRmResourceGroup -Force | Out-Null

            # Create the lab
            $createdLab = $lab | New-AzDtlLab

            # WORKAROUND for 1082372
            $lab | ForEach-Object {
                Set-AzResource -ResourceGroupName $_.ResourceGroupName -ResourceType 'Microsoft.DevTestLab/labs/users' -Name "$($_.Name)/@me" -ApiVersion 2018-10-15-preview -Force
            }

            $createdLab | Should -Not -Be $null
            $createdLab | Out-String | Write-Verbose

            # Add the Shared Image Gallery
            SetSharedImageGalleryWithDelay $lab $SharedImageGalleryId

            # Confirm SIG set correctly
            GetSharedImageGalleryWithDelay $lab | Should -Not -Be $null

        }

        It 'Can set individual images as enabled or disabled' {

            Write-Verbose 'Getting the SIG with images'
            $SIG = GetSharedImageGalleryWithDelay $lab
            $SIG.Images | Should -Not -Be $null

            # At this point - we've got the images!  Let's pick the first Windows one and set it to disabled
            $image = $SIG.Images | Where-Object {$_.OsType -eq "Windows"} | Select-Object -First 1

            # We have to slow down our script a bit, give the back end time to catch up on processing the list of images from SIG over to DTL
            $SIG | Set-AzDtlLabSharedImageGalleryImages -ImageName $image.definitionName -OsType $image.osType -ImageType $image.imageType -Enabled $false
            Start-Sleep -Seconds 60
            
            # Get the images, confirm it was set the right way
            $sigImageResult = (GetSharedImageGalleryImagesWithDelay $SIG | Where-Object {$_.OsType -eq "Windows"} | Select-Object -First 1).enableState
            $sigImageResult | Should -Be "Disabled"
            
            # Set again, to enabled
            $SIG = $lab | Get-AzDtlLabSharedImageGallery -IncludeImages
            $SIG | Set-AzDtlLabSharedImageGalleryImages -ImageName $image.definitionName -OsType $image.osType -ImageType $image.imageType -Enabled $true
            Start-Sleep -Seconds 60
            
            # Get the images, confirm it was set the right way
            $sigImageResult = (GetSharedImageGalleryImagesWithDelay $SIG | Where-Object {$_.OsType -eq "Windows"} | Select-Object -First 1).enableState
            $sigImageResult | Should -Be "Enabled"

        }

        It 'Can update all the images as enabled or disabled together' {

            Write-Verbose 'Getting the SIG with images'
            $SIG = GetSharedImageGalleryWithDelay $lab

            $SIG.Images | Format-Table | Out-String | Write-Verbose
            Write-Verbose "Images Count: $($SIG.Images.Count)"

            $SIG.Images | ForEach-Object {
                    # Set them all to disabled
                    $_.enableState = "Disabled"
                 }

            $SIG | Set-AzDtlLabSharedImageGalleryImages

            # Confirm they're all set to disabled
            GetSharedImageGalleryImagesWithDelay $SIG | ForEach-Object {
                $_.enableState | Should -Be "Disabled"
            }

            # Set them all back to enabled
            $SIG.Images | ForEach-Object {
                    # Set them all to enabled
                    $_.enableState = "Enabled"
                 }

            $SIG | Set-AzDtlLabSharedImageGalleryImages

            # Confirm they're all set to enabled
            GetSharedImageGalleryImagesWithDelay $SIG | ForEach-Object {
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
