[CmdletBinding()]
param()

Import-Module ..\Az.AzureLabs.psm1 -Force

$la  = Get-AzLabAccount -LabAccountName Hogwarts
$gim = ($la | Get-AzLabAccountGalleryImage)[0] # Pick the first image, also have a Get-AzLabAccountSharedImage

$lab = $la `
    | New-AzLab -LabName GalleryLab4 -MaxUsers 2 -UsageQuotaInHours 31 -UserAccessMode Restricted -SharedPasswordEnabled `
    | New-AzLabTemplateVM -Image $gim -Size Medium -Title "New Gallery" -Description "New Description" -UserName test0000 -Password Test00000000 `
    | Publish-AzLab `
    | Add-AzLabUser -Emails @('lucabol@microsoft.com')

$user = $lab | Get-AzLabUser -Email 'lucabol*'

$vm = $lab | Get-AzLabVm -ClaimByUser $user

$lab | Remove-AzLabuser -User $user

$lab | Remove-AzLab
Remove-Module Az.AzureLabs -Force