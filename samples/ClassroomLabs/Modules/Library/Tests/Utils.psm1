Import-Module $PSScriptRoot\..\Az.LabServices.psm1

$rgName = 'AzLabsLibrary'
$rgLocation = 'West US'

$labName = 'FastLab'
$laName = 'AzLabsLibrary-la'
$imgName = 'CentOS-based*'
$usageQuota = 3000
$shPsswd = $true
$size = 'Basic'
$userName = 'test0000'
$password = 'Test00000000'
$linuxRdp = $true

function Get-FastResourceGroup {
    [CmdletBinding()]
    param()

    Write-Host "Get-FastResourceGroup: Getting resource group $rgName"
    $rg = Get-AzResourceGroup -ResourceGroupName $rgName -EA SilentlyContinue
    if (-not $rg) {
        Write-Verbose "Get-FastResourceGroup: $rg does not exist creating."
        New-AzResourceGroup -ResourceGroupName $rgName -Location $rgLocation | Out-null
        Start-Sleep -Seconds 5
        $rg = Get-AzResourceGroup -ResourceGroupName $rgName -EA SilentlyContinue
        Write-Verbose "Get-FastResourceGroup: $rgname resource group didn't exist. Created it."
    }
    return $rg
}

function Get-FastLabAccount {
    [CmdletBinding()]
    param([Switch]$RandomName = $false)

    # Creat RG, Lab Account and lab if not existing
    Write-Verbose "Get-FastLabAccount: Getting RG"
    $la = Get-FastResourceGroup 
    Write-Verbose "Get-FastLabAccount: Returned RG $($la.ResourceGroupName)"
    $rgName = $la.ResourceGroupName
    
    if($RandomName) {
        $laRealName = 'Temp' + (Get-Random)
    } else {
        $laRealName = $laName
    }
    Write-Verbose "Get-FastLabAccount: laRealName $laRealName"
    $la = Get-AzLabAccount -ResourceGroupName $rgName -LabAccountName $laRealName
    if (-not $la) {
        Write-Verbose "Get-FastLabAccount: Creating new lab account."
        $la = New-AzLabAccount -ResourceGroupName $rgName -LabAccountName $laRealName
        Write-Host "$laRealName lab account created."                
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

    Write-Verbose "Get-FastLab: Lab name $labRealName"

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
          
        Write-Verbose "Get-FastLab: Image $img"
        Write-Verbose "Get-FastLab: Linux RDP $linuxRdp"

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
    $allsg = Get-AzGallery -ResourceGroupName 'AzLabsLibrary'
    Write-Verbose "Get-FastGallery: Shared Galleries $allsg"
    $allsg | Should -Not -BeNullOrEmpty | Write-Host "Missing Shared Image Gallery."
    $sg = $allsg `
         | Where-Object { (Get-AzGalleryImageDefinition -ResourceGroupName $_.ResourceGroupName -GalleryName $_.Name).Count -gt 0 }

    $sg | Should -Not -BeNullOrEmpty | Write-Host "Missing images in $sg"
    return $sg[0]
}

Export-ModuleMember -Function   Get-FastResourceGroup,
                                Get-FastLabAccount,
                                Get-FastLab,
                                Get-FastGallery