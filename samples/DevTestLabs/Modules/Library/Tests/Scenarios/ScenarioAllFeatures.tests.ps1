<#
This highlights most features in the library, the composibility of the functions and how to run them in parallel.
#>
Import-Module $PSScriptRoot\..\..\Az.DevTestLabs2.psm1

function StringToFile([parameter(ValueFromPipeline=$true)][string] $text) {
  $tmp = New-TemporaryFile
  Set-Content -Path $tmp.FullName -Value $text
  return $tmp.FullName
}

$lab1 = "DtlLibraryTest" + (Get-Random)
$lab2 = "DtlLibraryTest" + (Get-Random)
$rgName = "DtlLibraryTestRG" + (Get-Random)

$labsData = @"
Name, ResourceGroupName
$lab1, $rgName
$lab2, $rgName
"@

Describe  'Scenario Tests' {

    Context 'All Features' {

      It 'Can use library features together in a pipeline' {

        New-AzureRmResourceGroup -Name $rgName -Location 'West Europe' | Out-Null

        $labs = $labsData `
                | StringToFile `
                | Import-Csv `
                | New-AzDtlLab -AsJob `
                | Receive-Job -Wait
        
        $labs `
          | Add-AzDtlLabUser -UserEmail 'lucabol@microsoft.com' `
          | Set-AzDtlLabAnnouncement -Title 'I am here' -AnnouncementMarkDown 'yep' `
          | Set-AzDtlLabSupport -SupportMarkdown "### Sample lab announcement header." `
          | Set-AzDtlLabRdpSettings -GatewayUrl 'Agtway@adomain.com' -ExperienceLevel 5 `
          | Set-AzDtlLabShutdown -ShutdownTime '21:00' -TimeZoneId 'UTC' -ScheduleStatus 'Enabled' -NotificationSettings 'Enabled' `
              -TimeInIMinutes 50 -ShutdownNotificationUrl 'https://blah.com' -EmailRecipient 'blah@lab.com' `
          | Set-AzDtlLabStartupSchedule -StartupTime '21:00' -TimeZoneId 'UTC' -WeekDays @('Monday') `
          | Add-AzDtlLabArtifactRepository -ArtifactRepoUri 'https://github.com/lucabol/DTLWorkshop.git' `
              -artifactRepoSecurityToken '196ad1f5b5464de4de6d47705bbcab0ce7d323fe' `
          | New-AzDtlVm -VmName ("vm" + (Get-Random)) -Size 'Standard_A4_v2' -Claimable -UserName 'bob' -Password 'aPassword341341' `
              -OsType Windows -Sku '2012-R2-Datacenter' -Publisher 'MicrosoftWindowsServer' -Offer 'WindowsServer' `
              -AsJob `
          | Receive-Job -Wait `
          | Start-AzDtlVm `
          | Set-AzDtlVmArtifact -RepositoryName 'Public Artifact Repo' -ArtifactName 'windows-7zip' `
          | Set-AzDtlVmAutoStart `
          | Set-AzDtlVmShutdownSchedule -ShutdownTime '20:00' -TimeZoneId 'UTC' `
          | Invoke-AzDtlVmClaim `
          | Stop-AzDtlVm `
          | Remove-AzDtlVm
        
        $labs | Get-AzDtlLabSchedule -ScheduleType 'AutoShutdown' | Out-Null
        
        $customImage = $labs[0] `
          | New-AzDtlVm -VmName ("cvm" + (Get-Random)) -Size 'Standard_A4_v2' -Claimable -UserName 'bob' -Password 'aPassword341341' `
            -OsType Windows -Sku '2012-R2-Datacenter' -Publisher 'MicrosoftWindowsServer' -Offer 'WindowsServer' `
          | New-AzDtlCustomImageFromVm -ImageName ("im" + (Get-Random)) -ImageDescription 'Created using Azure DevTest Labs PowerShell library.'
        
        $labs[0] | New-AzDtlVm -CustomImage $customImage -VmName ('cvm2' + (Get-Random)) -Size 'Standard_A4_v2' -OsType Windows | Out-Null
        
      }

      It 'Clean up resources' {

        $labs = $labsData `
        | StringToFile `
        | Import-Csv `
        | Get-AzDtlLab
        
        $labs | Remove-AzDtlLab
        Remove-AzureRmResourceGroup -Name $rgName -Force | Out-Null
      }
    }
}
