<#
This highlights most features in the library, the composibility of the functions and how to run them in parallel.
#>
[CmdletBinding()]
param()

function StringToFile([parameter(ValueFromPipeline=$true)][string] $text) {
  $tmp = New-TemporaryFile
  Set-Content -Path $tmp.FullName -Value $text
  return $tmp.FullName
}

Import-Module ..\Az.DevTestLabs2.psm1 -Force

$lab1 = "Test" + (Get-Random)
$lab2 = "Test" + (Get-Random)
$rgName = "TeRG" + (Get-Random)

New-AzureRmResourceGroup -Name $rgName -Location 'West Europe' | Out-Null

$labsData = @"
Name, ResourceGroupName
$lab1, $rgName
$lab2, $rgName
"@

$labs = $labsData `
        | StringToFile `
        | Import-Csv `
        | Dtl-NewLab -AsJob `
        | Receive-Job -Wait

$labs `
  | Dtl-AddUser -UserEmail 'lucabol@microsoft.com' `
  | Dtl-SetLabAnnouncement -Title 'I am here' -AnnouncementMarkDown 'yep' `
  | Dtl-SetLabSupport -SupportMarkdown "### Sample lab announcement header." `
  | Dtl-SetLabRdp -GatewayUrl 'Agtway@adomain.com' -ExperienceLevel 5 `
  | Dtl-SetLabShutdown -ShutdownTime '21:00' -TimeZoneId 'UTC' -ScheduleStatus 'Enabled' -NotificationSettings 'Enabled' `
      -TimeInIMinutes 50 -ShutdownNotificationUrl 'https://blah.com' -EmailRecipient 'blah@lab.com' `
  | Dtl-SetLabStartup -StartupTime '21:00' -TimeZoneId 'UTC' -WeekDays @('Monday') `
  | Dtl-AddLabRepo -ArtifactRepoUri 'https://github.com/lucabol/DTLWorkshop.git' `
      -artifactRepoSecurityToken '196ad1f5b5464de4de6d47705bbcab0ce7d323fe' `
  | Dtl-NewVm -VmName ("vm" + (Get-Random)) -Size 'Standard_A4_v2' -Claimable -UserName 'bob' -Password 'aPassword341341' `
      -OsType Windows -Sku '2012-R2-Datacenter' -Publisher 'MicrosoftWindowsServer' -Offer 'WindowsServer' `
      -AsJob `
  | Receive-Job -Wait `
  | Dtl-StartVm `
  | Dtl-ApplyArtifact -RepositoryName 'Public Artifact Repo' -ArtifactName 'windows-7zip' `
  | Dtl-SetAutoStart `
  | Dtl-SetVmShutdown -ShutdownTime '20:00' -TimeZoneId 'UTC' `
  | Dtl-ClaimVm `
  | Dtl-StopVm `
  | Dtl-RemoveVm

$labs | Dtl-GetLabSchedule -ScheduleType 'AutoShutdown' | Out-Null

$customImage = $labs[0] `
  | Dtl-NewVm -VmName ("cvm" + (Get-Random)) -Size 'Standard_A4_v2' -Claimable -UserName 'bob' -Password 'aPassword341341' `
    -OsType Windows -Sku '2012-R2-Datacenter' -Publisher 'MicrosoftWindowsServer' -Offer 'WindowsServer' `
  | Dtl-NewCustomImage -ImageName ("im" + (Get-Random)) -ImageDescription 'Created using Azure DevTest Labs PowerShell library.'

$labs[0] | Dtl-NewVm -CustomImage $customImage -VmName ('cvm2' + (Get-Random)) -Size 'Standard_A4_v2' -OsType Windows | Out-Null

$labs | Dtl-RemoveLab
Remove-AzureRmResourceGroup -Name $rgName | Out-Null

Remove-Module Az.DevTestLabs2 -Force -Verbose:$false
