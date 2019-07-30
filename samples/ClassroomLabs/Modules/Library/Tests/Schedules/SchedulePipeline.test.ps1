Import-Module $PSScriptRoot\..\..\Az.LabServices.psm1

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
                Write-Host "$rgname resource group didn't exist. Created it."
            }
            
            $la  = New-AzLabAccount -ResourceGroupName $rgName -LabAccountName $laName
            Write-Host "$laName lab account created or found."
            
            $lab = $la | Get-AzLab -LabName $labName
            
            if($lab) {
                $lab = $la `
                    | New-AzLab -LabName $LabName -MaxUsers $maxUsers -UsageQuotaInHours $usageQuota -UserAccessMode $usageAMode -SharedPasswordEnabled:$shPsswd `
                    | Publish-AzLab
                Write-Host "$LabName lab already exist. Republished."
            } else {
                $img = $la | Get-AzLabAccountGalleryImage | Where-Object {$_.name -like $imgName}
                if(-not $img -or $img.Count -ne 1) {Write-Error "$imgName pattern doesn't match just one image."}
                Write-Host "Image $imgName found."
                
                $lab = $la `
                    | New-AzLab -LabName $LabName -MaxUsers $maxUsers -UsageQuotaInHours $usageQuota -UserAccessMode $usageAMode -SharedPasswordEnabled:$shPsswd `
                    | New-AzLabTemplateVM -Image $img -Size $size -Title $title -Description $descr -UserName $userName -Password $password -LinuxRdpEnabled:$linuxRdp `
                    | Publish-AzLab
                Write-Host "$LabName lab doesn't exist. Created it."
            }
            
            # Create Schedules
            $schedules | ForEach-Object { $_ | New-AzLabSchedule -Lab $lab} | Out-Null
            Write-Host "Added all schedules."

            # Get Schedules
            $created = $lab | Get-AzLabSchedule
            $created | Should -HaveCount $schedules.Count

            # Remove Schedules
            $created | Remove-AzLabSchedule

            # Cleanup
            Remove-AzResourceGroup -ResourceGroupName $rgName -Force
                        
        }
    }
}