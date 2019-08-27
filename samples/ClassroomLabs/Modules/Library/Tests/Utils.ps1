Import-Module $PSScriptRoot\..\Az.LabServices.psm1

$rgName = 'AzLabsLibrary'
$rgLocation = 'West Europe'
$labName = 'FastLab'
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
$password = 'Test000'

function Get-FastResourceGroup {
    [CmdletBinding()]
    param()

    $rg = Get-AzResourceGroup -ResourceGroupName $rgName -EA SilentlyContinue
    if (-not $rg) {
        New-AzResourceGroup -ResourceGroupName $rgName -Location $rgLocation | Out-null
        Write-Verbose "$rgname resource group didn't exist. Created it."
    }
    return $rg
}

function Get-FastLabAccount {
    [CmdletBinding()]
    param([Switch]$RandomName = $false)

    # Creat RG, Lab Account and lab if not existing
    Get-FastResourceGroup | Out-Null
    
    if($RandomName) {
        $laRealName = 'Temp' + (Get-Random)
    } else {
        $laRealName = $laName
    }

    $la = Get-AzLabAccount -ResourceGroupName $rgName -LabAccountName $laRealName
    if (-not $la) {
        $la = New-AzLabAccount -ResourceGroupName $rgName -LabAccountName $laRealName
        Write-Verbose "$laRealName lab account created."                
    }
    return $la
}

function Get-FastLab {
    [CmdletBinding()]
    param([Switch]$RandomName = $false)

    $la = Get-FastLabAccount
 
    if($RandomName) {
        $labRealName = 'Temp' + (Get-Random)
    } else {
        $labRealName = $labName
    }

    $lab = $la | Get-AzLab -LabName $labRealName
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
        | New-AzLab -LabName $LabRealName -MaxUsers $maxUsers -UsageQuotaInHours $usageQuota -UserAccessMode $usageAMode -SharedPasswordEnabled:$shPsswd `
        | New-AzLabTemplateVM -Image $img -Size $size -Title $title -Description $descr -UserName $userName -Password $password -LinuxRdpEnabled:$linuxRdp `
        | Publish-AzLab
        Write-Verbose "$LaRealbName lab doesn't exist. Created it."
        return $lab
    }
}

# Returns the first shared image gallery in the subscription with images in it
function Get-FastGallery {
    [CmdletBinding()]
    param()
    $allsg = Get-AzGallery
    $sg = $allsg `
         | Where-Object {$_.Name.StartsWith('AzLabsTestGallery')} `
         | Where-Object { (Get-AzGalleryImageDefinition -ResourceGroupName $_.ResourceGroupName -GalleryName $_.Name).Count -gt 0 }
    if($sg) {
        return $sg[0]
    } else {
        Write-Error "No shared image gallery with images exist in this subscription"
    }
}

