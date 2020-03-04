[CmdletBinding()]
param()

Import-Module ..\Az.LabServices.psm1 -Force

$acName     = "Test" + (Get-Random)
$labName    = "Test" + (Get-Random)
$rgName     = "TeRG" + (Get-Random)

New-AzureRmResourceGroup -Name $rgName -Location 'West Europe' | Out-Null

$la  = New-AzLabAccount -ResourceGroupName $rgName -LabAccountName $acName
$gim = ($la | Get-AzLabAccountGalleryImage)[0] # Pick the first image, also have a Get-AzLabAccountSharedImage

$lab = $la `
    | New-AzLab -LabName $LabName -Image $gim -Size Basic -UsageQuotaInHours 31 -SharedPasswordEnabled -UserName test0000 -Password Test00000000 `
    | Publish-AzLab `
    | Add-AzLabUser -Emails @('lucabol@microsoft.com') `
    | Set-AzLab -UsageQuotaInHours 20

$user = $lab | Get-AzLabUser -Email 'lucabol*'
$lab | Send-AzLabUserInvitationEmail -User $user -InvitationText 'Running tests'

$vm = $lab | Get-AzLabVm -ClaimByUser $user

$today  = (Get-Date).ToString()
$end    = (Get-Date).AddMonths(4).ToString()

$lab | New-AzLabSchedule -Frequency Weekly -FromDate $today -ToDate $end -StartTime '10:00' -EndTime '11:00' -Notes 'A classroom note.' | Out-Null
$lab | Get-AzLabSchedule `
     | Remove-AzLabSchedule

$lab | Remove-AzLabuser -User $user
$lab | Remove-AzLab

Remove-AzLabAccount -LabAccount $la
Remove-AzureRmResourceGroup -Name $rgName -Force | Out-Null
Remove-Module Az.LabServices -Force