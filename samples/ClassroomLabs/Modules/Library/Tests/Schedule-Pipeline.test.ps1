Import-Module $PSScriptRoot\..\Az.LabServices.psm1
$VerbosePreference="Continue"

$today      = (Get-Date).ToString()
$tomorrow   = (Get-Date).AddDays(1)
$end        = (Get-Date).AddMonths(4).ToString()

$rgName     = 'Acme' + (Get-Random)
$rgLocation = 'West Europe'
$labName    = 'Advancing Differenciation'
$laName     = 'Workshops'
$imgName    = 'CentOS-Based*'
$maxUsers   = 2
$usageQuota = 30
$usageAMode = 'Restricted'
$shPsswd    = $false
$size       = 'Medium'
$title      = 'Advancing Differentiation Workshop'
$descr      = 'Bringing it to the 21st Century'
$userName   = 'test0000'
$password   = 'Test00000000'
$linuxRdp   = $true

$schedules  = @(
    [PSCustomObject]@{Frequency='Weekly';FromDate=$today;ToDate = $end;StartTime='10:00';EndTime='11:00';Notes='Theory'}
    [PSCustomObject]@{Frequency='Weekly';FromDate=$tomorrow;ToDate = $end;StartTime='11:00';EndTime='12:00';Notes='Practice'}
)

Describe 'Schedule Management' {
    Context 'Pipeline Tests' {
        It 'Can create a schedule, get it and delete it' {

            # Creat RG, Lab Account and lab if not existing
            if(-not (Get-AzResourceGroup -ResourceGroupName $rgName -EA SilentlyContinue)) {
                New-AzResourceGroup -ResourceGroupName $rgName -Location $rgLocation | Out-null
                Write-Verbose "$rgname resource group didn't exist. Created it."
            }
            
            $la  = New-AzLabAccount -ResourceGroupName $rgName -LabAccountName $laName
            Write-Verbose "$laName lab account created or found."
            
            $lab = $la | Get-AzLab -LabName $labName
            
            if($lab) {
                $lab = $la `
                    | New-AzLab -LabName $LabName -MaxUsers $maxUsers -UsageQuotaInHours $usageQuota -UserAccessMode $usageAMode -SharedPasswordEnabled:$shPsswd `
                    | Publish-AzLab
                Write-Verbose "$LabName lab already exist. Republished."
            } else {
                $imgs = $la | Get-AzLabAccountGalleryImage
                $imgs | Should -Not -Be $null
                # $imgs.Count | Should -BeGreaterThan 0
                $img = $imgs[0]
                $img | Should -Not -Be $null
                Write-Verbose "Image $imgName found."
                
                $lab = $la `
                    | New-AzLab -LabName $LabName -MaxUsers $maxUsers -UsageQuotaInHours $usageQuota -UserAccessMode $usageAMode -SharedPasswordEnabled:$shPsswd `
                    | New-AzLabTemplateVM -Image $img -Size $size -Title $title -Description $descr -UserName $userName -Password $password -LinuxRdpEnabled:$linuxRdp `
                    | Publish-AzLab
                Write-Verbose "$LabName lab doesn't exist. Created it."
            }
            
            # Create Schedules
            $schedules | ForEach-Object { $_ | New-AzLabSchedule -Lab $lab} | Out-Null
            Write-Verbose "Added all schedules."

            # Get Schedules
            $created = $lab | Get-AzLabSchedule
            $created | Should -HaveCount $schedules.Count

            # Remove Schedules
            $created | Remove-AzLabSchedule
            $existing = $lab | Get-AzLabSchedule
            $existing | Should -HaveCount 0

            # Cleanup
            Remove-AzResourceGroup -ResourceGroupName $rgName -Force
                        
        }
    }
}
