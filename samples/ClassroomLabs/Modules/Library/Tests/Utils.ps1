Import-Module $PSScriptRoot\..\Az.LabServices.psm1

# $suffix = if(-not $IsCoreCLR) {"Powershell"} elseif($IsLinux) {"Linux"} elseif($IsMacOS) {"MacOS"} else {""}
# $rgName = 'AzLabsLibrary' + $suffix
$rgName = 'AzLabsLibrary'
$rgLocation = 'West Europe'

$labName = 'FastLab'
$laName = 'AzLabsLibrary-la'
$imgName = 'CentOS-Based*'
$usageQuota = 30
$shPsswd = $false
$size = 'Basic'
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
    $la = Get-FastResourceGroup 
    $rgName = $la.ResourceGroupName
    
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
        | New-AzLab -LabName $LabRealName -Image $img -Size $size -UsageQuotaInHours $usageQuota -UserName $userName -Password $password -LinuxRdpEnabled:$linuxRdp -SharedPasswordEnabled:$shPsswd `
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

