Import-Module ..\Az.AzureLabs.psm1 -Force

$la  = Get-AzLabAccount -LabAccountName Hogwarts
$gim = ($la | Get-AzLabAccountGalleryImage)[0] # Pick the first image, also have a Get-AzLabAccountSharedImage

$lab = $la `
    | New-AzLab -LabName GalleryLab3 -MaxUsers 2 -UsageQuotaInHours 31 -UserAccessMode Restriced -SharedPasswordEnabled `
    | New-AzLabTemplateVM -Image $gim -Size Medium -Title "New Gallery" -Description "New Description" -UserName test0000 -Password Test00000000 `
    | Publish-AzLab

# functions I have not implemented yet to add users, etc ...

$lab | Remove-AzLab
Remove-Module Az.DevTestLabs2 -Force