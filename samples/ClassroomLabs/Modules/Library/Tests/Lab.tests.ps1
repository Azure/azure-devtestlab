[cmdletbinding()]
Param()
Import-Module $PSScriptRoot\..\Az.LabServices.psm1

. $PSScriptRoot\Utils.ps1

$labName = 'TestLab' + (Get-Random)
$imgName = 'CentOS-Based*'
$usageQuota = 30
$shPsswd = $false
$size = 'Basic'
$userName = 'test0000'
$password = 'Test00000000'
$linuxRdp = $true

Describe 'Lab' {

    BeforeAll {
        $script:la = Get-FastLabAccount
    }

    # This should be split in two tests for create and set
    It 'Can create a lab' {
                 
        $imgs = $script:la | Get-AzLabAccountGalleryImage
        $imgs | Should -Not -Be $null
        # $imgs.Count | Should -BeGreaterThan 0
        $img = $imgs[0]
        $img | Should -Not -Be $null
        Write-Verbose "Image $imgName found."
            
        $lab = $script:la `
        | New-AzLab -LabName $LabName -Image $img -Size $size -UsageQuotaInHours $usageQuota -SharedPasswordEnabled:$shPsswd -UserName $userName -Password $password -LinuxRdpEnabled:$linuxRdp `
        | Publish-AzLab
        Write-Verbose "$LabName lab doesn't exist. Created it."
            
        $lab | Should -Not -BeNullOrEmpty                   
    }
    It 'Can set a lab' {

        $lab = $script:la | Get-AzLab -LabName $labName
        $lab | Should -Not -BeNullOrEmpty                   

        $lab | Set-AzLab -MaxUsers 3 -UsageQuotaInHours 10 -UserAccessMode 'Restricted' -SharedPasswordEnabled | Out-Null
    }
    It 'Can set Title and description on template vm' {
        $lab = $script:la | Get-AzLab -LabName $labName
        $templateVm = $lab | Get-AzLabTemplateVM
        $templateVm | Should -Not -BeNullOrEmpty                   
           
        $templateVm | Set-AzLabTemplateVM -Title "Test Title" -Description "Test Desc"
    }
    It 'Can start and stop template vm' {
        $lab = $script:la | Get-AzLab -LabName $labName
        $templateVm = $lab | Get-AzLabTemplateVM
        $templateVm | Should -Not -BeNullOrEmpty
           
        $templateVm = $templateVm | Stop-AzLabTemplateVm
        $templateVm = $templateVm | Start-AzLabTemplateVm
        $templateVm | Should -Not -BeNullOrEmpty
    }

    It 'Can query using wildcards' {
        $script:la | Get-AzLab -LabName Fast* | Should -Not -BeNullOrEmpty
        $script:la | Get-AzLab -LabName FastLab | Should -Not -BeNullOrEmpty       
    }


    it 'Can remove a lab' {
        $lab = $script:la | Get-AzLab -LabName $labName

        $lab | Remove-AzLab
        Write-Verbose "Removed lab"
    }
}
