[CmdletBinding()]
param()

Import-Module ..\Az.AzureLabs.psm1 -Force

$la  = Get-AzLabAccount -LabAccountName Hogwarts
$gim = ($la | Get-AzLabAccountGalleryImage)[0] # Pick the first image, also have a Get-AzLabAccountSharedImage

$lab = $la `
    | New-AzLab -LabName GalleryLab6 -MaxUsers 2 -UsageQuotaInHours 31 -UserAccessMode Restricted -SharedPasswordEnabled `
    | New-AzLabTemplateVM -Image $gim -Size Medium -Title "New Gallery" -Description "New Description" -UserName test0000 -Password Test00000000 `
    | Publish-AzLab `
    | Add-AzLabUser -Emails @('lucabol@microsoft.com') `
    | Set-AzLab -MaxUsers 3 -UsageQuotaInHours 20

$user = $lab | Get-AzLabUser -Email 'lucabol*'
$lab | Send-AzLabUserInvitationEmail -User $user -InvitationText 'Running tests'
# How do I register a user to the lab, without him clicking on Register link?

$vm = $lab | Get-AzLabVm -ClaimByUser $user

$today  = (Get-Date).ToString()
$end    = (Get-Date).AddMonths(4).ToString()

$lab `
    | New-AzLabSchedule -Frequency Weekly -FromDate $today -ToDate $end -StartTime '10:00' -EndTime '11:00' -Notes 'A clarroom note.' `
    | Get-AzLabSchedule `
    | Remove-AzLabSchedule

$lab | Remove-AzLabuser -User $user
$lab | Remove-AzLab
Remove-Module Az.AzureLabs -Force