[cmdletbinding()]
Param()
Import-Module $PSScriptRoot\..\Az.LabServices.psm1

$rgName = 'AzLabsLibrary'
$rgLocation = 'West Europe'
$labName = 'TestLab'
$laName = 'AzLabsLibrary-la'
$imgName = 'CentOS-Based*'
$maxUsers = 2
$usageQuota = 30
$usageAMode = 'Restricted'
$shPsswd = $false
$size = 'Medium'
$title = 'Advancing Differentiation Workshop'
$descr = 'Bringing it to the 21st Century'
$userName = 'test0000'
$password = 'Test00000000'
$linuxRdp = $true

Describe 'Lab' {

    BeforeAll {
        if (-not (Get-AzResourceGroup -ResourceGroupName $rgName -EA SilentlyContinue)) {
            New-AzResourceGroup -ResourceGroupName $rgName -Location $rgLocation | Out-null
            Write-Verbose "$rgname resource group didn't exist. Created it."
        }

        $script:la = Get-AzLabAccount -ResourceGroupName $rgName -LabAccountName $laName
        if (-not $la) {
            $script:la = New-AzLabAccount -ResourceGroupName $rgName -LabAccountName $laName
            Write-Verbose "$laName lab account created."                
        }
    }

    It 'Can create a lab' {
                 
        $lab = $script:la | Get-AzLab -LabName $labName
            
        if ($lab) {
            $lab = $script:la `
            | New-AzLab -LabName $LabName -MaxUsers $maxUsers -UsageQuotaInHours $usageQuota -UserAccessMode $usageAMode -SharedPasswordEnabled:$shPsswd `
            | Publish-AzLab
            Write-Verbose "$LabName lab already exist. Republished."
        }
        else {
            $imgs = $script:la | Get-AzLabAccountGalleryImage
            $imgs | Should -Not -Be $null
            # $imgs.Count | Should -BeGreaterThan 0
            $img = $imgs[0]
            $img | Should -Not -Be $null
            Write-Verbose "Image $imgName found."
                
            $lab = $script:la `
            | New-AzLab -LabName $LabName -MaxUsers $maxUsers -UsageQuotaInHours $usageQuota -UserAccessMode $usageAMode -SharedPasswordEnabled:$shPsswd `
            | New-AzLabTemplateVM -Image $img -Size $size -Title $title -Description $descr -UserName $userName -Password $password -LinuxRdpEnabled:$linuxRdp `
            | Publish-AzLab
            Write-Verbose "$LabName lab doesn't exist. Created it."
        }
            
        $lab | Should -Not -BeNullOrEmpty                   
    }

    It 'Can query using wildcards' {
        $script:la | Get-AzLab -LabName Fast* | Should -Not -BeNullOrEmpty
        $script:la | Get-AzLab -LabName FastLab | Should -Not -BeNullOrEmpty       
    }


    it 'Can remove a lab' {
        $lab = $script:la | Get-AzLab -LabName $labName

        # OK, this is ugly. I am testing randomly both branches in the creation test by leaving the lab there half the time
        # In theory it should be two different tests, but We have issues of running time for tests, hence this hack ...

        if((Get-Random -Minimum 1 -Maximum 10) -lt 5) {
            $lab | Remove-AzLab
            Write-Verbose "Removed lab"
        }
    }
}
