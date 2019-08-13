Import-Module $PSScriptRoot\..\Az.LabServices.psm1

$rgName = 'TestPerm'
$rgLocation = 'West Europe'
$labName = 'FastLab'
$laName = 'LATest'
$imgName = 'CentOS-Based*'
$maxUsers = 2
$usageQuota = 30
$usageAMode = 'Restricted'
$shPsswd = $false
$size = 'Medium'
$title = 'Advancing Differentiation Workshop'
$descr = 'Bringing it to the 21st Century'
$userName = 'test0000'
$password = 'Test000'

function Get-FastLabAccount {
    [CmdletBinding()]
    param()

    # Creat RG, Lab Account and lab if not existing
    if (-not (Get-AzResourceGroup -ResourceGroupName $rgName -EA SilentlyContinue)) {
        New-AzResourceGroup -ResourceGroupName $rgName -Location $rgLocation | Out-null
        Write-Verbose "$rgname resource group didn't exist. Created it."
    }

    $la = Get-AzLabAccount -ResourceGroupName $rgName -LabAccountName $laName
    if (-not $la) {
        $la = New-AzLabAccount -ResourceGroupName $rgName -LabAccountName $laName
        Write-Verbose "$laName lab account created."                
    }
    return $la
}

function Get-FastLab {
    [CmdletBinding()]
    param()

    $la = Get-FastLabAccount
                
    $lab = $la | Get-AzLab -LabName $labName
    if ($lab) {
        return $lab
    }
    else {
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
        return $lab
    }
}


