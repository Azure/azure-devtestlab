[cmdletbinding()]
Param()
Import-Module $PSScriptRoot\..\Az.LabServices.psm1 -Force

#. $PSScriptRoot\Utils.ps1
Import-Module $PSScriptRoot\Utils.psm1 -Force
Write-Verbose "Loading Utils.psm1"

Describe 'Lab' {

    BeforeAll {

        $labName1 = "TestLab$(Get-Random)"
        #$imgName1 = "CentOS-Based*"
        $usageQuota1 = 30
        $shPsswd1 = $false
        $size1 = "Basic"
        $userName1 = "test0000"
        $password1 = "Test$(Get-Random)"
        $linuxRdp1 = $true

        $script:la = Get-FastLabAccount

    }

    # This should be split in two tests for create and set
    It 'Can create a lab' {
                 

        $imgs = $script:la | Get-AzLabAccountGalleryImage
        $imgs | Should -Not -Be $null
        # $imgs.Count | Should -BeGreaterThan 0
        $img = $imgs[0]
        $img | Should -Not -Be $null
        Write-Verbose "Image $img found."
        
        Write-Verbose "Lab.Tests: Linux1 $linuxRdp1"
        Write-Verbose "Lab.Tests: LabName1 $labName1"
        Write-Verbose "Lab.Tests: la $($script:la)"

        $lab = $script:la `
        | New-AzLab -LabName $labName1 -Image $img -Size $size1 -UsageQuotaInHours $usageQuota1 -SharedPasswordEnabled:$shPsswd1 -UserName $userName1 -Password $password1 -LinuxRdp:$linuxRdp1 `
        | Publish-AzLab
        
        Write-Verbose "$labName1 lab doesn't exist. Created it."
            
        $lab | Should -Not -BeNullOrEmpty                   
    }
    It 'Can set a lab' {

        $lab = $script:la | Get-AzLab -LabName $labName1
        $lab | Should -Not -BeNullOrEmpty                   

        $lab | Set-AzLab -MaxUsers 3 -UsageQuotaInHours 10 -UserAccessMode 'Restricted' -SharedPasswordEnabled 'Enabled' | Out-Null
    }
    It 'Can set Title and description on template vm' {
        $lab = $script:la | Get-AzLab -LabName $labName1
        $templateVm = $lab | Get-AzLabTemplateVM
        $templateVm | Should -Not -BeNullOrEmpty                   
           
        $templateVm | Set-AzLabTemplateVM -Title "Test Title" -Description "Test Desc"
    }
    It 'Can start and stop template vm' {
        $lab = $script:la | Get-AzLab -LabName $labName1
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
        $lab = $script:la | Get-AzLab -LabName $labName1

        $lab | Remove-AzLab
        Write-Verbose "Removed lab"
    }
}
