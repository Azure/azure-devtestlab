[CmdletBinding()]
param(
    [parameter(Mandatory = $true, ValueFromPipelineByPropertyName = $true)]
    [string]
    $CsvConfigFile
)

Import-Module ../Az.AzureLabs.psm1

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$init = {
    function New-AzLabSingle {
        [CmdletBinding()]
        [Diagnostics.CodeAnalysis.SuppressMessageAttribute("PSAvoidUsingPlainTextForPassword", "", Scope = "Function")]
        param(
            [parameter(Mandatory = $true, ValueFromPipelineByPropertyName = $true)]
            [ValidateNotNullOrEmpty()]
            $ResourceGroupName,

            [parameter(Mandatory = $true, ValueFromPipelineByPropertyName = $true)]
            [ValidateNotNullOrEmpty()]
            $Location,

            [parameter(Mandatory = $true, ValueFromPipelineByPropertyName = $true)]
            [ValidateNotNullOrEmpty()]
            $LabAccountName,

            [parameter(Mandatory = $true, ValueFromPipelineByPropertyName = $true)]
            [ValidateNotNullOrEmpty()]
            $LabName,

            [parameter(Mandatory = $true, ValueFromPipelineByPropertyName = $true)]
            [ValidateNotNullOrEmpty()]
            $ImageName,

            [parameter(Mandatory = $true, ValueFromPipelineByPropertyName = $true)]
            [int]
            $MaxUsers,

            [parameter(Mandatory = $true, ValueFromPipelineByPropertyName = $true)]
            [int]
            $UsageQuota,

            [parameter(Mandatory = $true, ValueFromPipelineByPropertyName = $true)]
            [ValidateSet('Restricted', 'Open')]
            $UsageMode,

            [parameter(Mandatory = $true, ValueFromPipelineByPropertyName = $true)]
            [bool]
            $SharedPassword,

            [parameter(Mandatory = $true, ValueFromPipelineByPropertyName = $true)]
            [ValidateSet('Small', 'Medium', 'MediumNested', 'Large', 'GPU')]
            $Size,

            [parameter(Mandatory = $true, ValueFromPipelineByPropertyName = $true)]
            [string]
            $Title,

            [parameter(Mandatory = $true, ValueFromPipelineByPropertyName = $true)]
            [string]
            $Descr,

            [parameter(Mandatory = $true, ValueFromPipelineByPropertyName = $true)]
            [string]
            $UserName,

            [parameter(Mandatory = $true, ValueFromPipelineByPropertyName = $true)]
            [string]
            $Password,

            [parameter(Mandatory = $true, ValueFromPipelineByPropertyName = $true)]
            [bool]
            $LinuxRdp,

            [parameter(Mandatory = $true, ValueFromPipelineByPropertyName = $true)]
            [string[]]
            $Emails,

            [parameter(Mandatory = $true, ValueFromPipelineByPropertyName = $true)]
            [string]
            $Invitation,

            [parameter(Mandatory = $false, ValueFromPipelineByPropertyName = $true)]
            $Schedules
        )

        <#
$today      = (Get-Date).ToString()
$tomorrow   = (Get-Date).AddDays(1)
$end        = (Get-Date).AddMonths(4).ToString()

$schedules  = @(
    [PSCustomObject]@{Frequency='Weekly';FromDate=$today;ToDate = $end;StartTime='10:00';EndTime='11:00';Notes='Theory'}
    [PSCustomObject]@{Frequency='Weekly';FromDate=$tomorrow;ToDate = $end;StartTime='11:00';EndTime='12:00';Notes='Practice'}
)
 #>
        Write-Host "Start creation of $LabName"

        $la = Get-AzLabAccount -ResourceGroupName $ResourceGroupName -LabAccountName $LabAccountName

        $lab = $la | Get-AzLab -LabName $LabName

        if ($lab) {
            $lab = $la `
            | New-AzLab -LabName $LabName -MaxUsers $maxUsers -UsageQuotaInHours $usageQuota -UserAccessMode $UsageMode -SharedPasswordEnabled:$SharedPassword `
            | Publish-AzLab
            Write-Host "$LabName lab already exist. Republished."
        }
        else {
            $img = $la | Get-AzLabAccountGalleryImage | Where-Object { $_.name -like $ImageName }
            if (-not $img -or $img.Count -ne 1) { Write-Error "$ImageName pattern doesn't match just one image." }
            Write-Host "Image $ImageName found."
    
            $lab = $la `
            | New-AzLab -LabName $LabName -MaxUsers $maxUsers -UsageQuotaInHours $usageQuota -UserAccessMode $UsageMode -SharedPasswordEnabled:$SharedPassword `
            | New-AzLabTemplateVM -Image $img -Size $size -Title $title -Description $descr -UserName $userName -Password $password -LinuxRdpEnabled:$linuxRdp `
            | Publish-AzLab
            Write-Host "$LabName lab doesn't exist. Created it."
        }

        $lab | Add-AzLabUser -Emails $emails | Out-Null
        $users = $lab | Get-AzLabUser
        $users | ForEach-Object { $lab | Send-AzLabUserInvitationEmail -User $_ -InvitationText $invitation } | Out-Null
        Write-Host "Added Users: $emails."

        if ($Schedules) {
            $schedules | ForEach-Object { $_ | New-AzLabSchedule -Lab $lab } | Out-Null
            Write-Host "Added all schedules."
        }
    }
}

# TODO: could parallelize this to make it faster (but not too slow anyhow)
function New-ResourceGroups {
    [CmdletBinding()]
    param(
        [parameter(Mandatory = $true, ValueFromPipeline = $true)]
        [psobject[]]
        $ConfigObject
    )

    $Rgs = $ConfigObject | Select-Object -Property ResourceGroupName, Location -Unique
    Write-Host "Operating on the following RGs:"
    Write-Host $Rgs
    
    $Rgs | ForEach-Object {
        if (-not (Get-AzResourceGroup -ResourceGroupName $_.ResourceGroupName -EA SilentlyContinue)) {
            New-AzResourceGroup -ResourceGroupName $_.ResourceGroupName -Location $_.Location | Out-null
            Write-Host "$($_.ResourceGroupName) resource group didn't exist. Created it."
        }
    }
}

# TODO: parallelize this one as it takes a few minutes ...
function New-Accounts {
    [CmdletBinding()]
    param(
        [parameter(Mandatory = $true, ValueFromPipeline = $true)]
        [psobject[]]
        $ConfigObject
    )

    $lacs = $ConfigObject | Select-Object -Property ResourceGroupName, LabAccountName -Unique
    Write-Host "Operating on the following Lab Accounts:"
    Write-Host $lacs
    
    $lacs | ForEach-Object {
        New-AzLabAccount -ResourceGroupName $_.ResourceGroupName -LabAccountName $_.LabAccountName | Out-Null
        Write-Host "$($_.LabAccountName) lab account created or found."
    }
}

function New-AzLabMultiple {
    [CmdletBinding()]
    param(
        [parameter(Mandatory = $true, ValueFromPipeline = $true)]
        [psobject[]]
        $ConfigObject
    )

    $block = {
        param($path)

        Set-StrictMode -Version Latest
        $ErrorActionPreference = 'Stop'
        
        $modulePath = Join-Path $path '..' 'Az.AzureLabs.psm1'
        Import-Module $modulePath
        # Really?? It got to be the lines below? Doing a ForEach doesn't work ...
        $input.movenext() | Out-Null
        $obj = $input.current[0]
        $obj | New-AzLabSingle
    }

    Write-Host "Starting creation of all labs in parallel. This can take a while. Go get multiple coffees."

    $jobs = $ConfigObject | ForEach-Object {
        Start-Job  -InitializationScript $init -ScriptBlock $block -ArgumentList $PSScriptRoot -InputObject $_ -Name $_.LabName
    }

    $jobs | Wait-Job | Receive-Job -Keep
}

$labs = Import-Csv -Path $CsvConfigFile

$labs | Format-Table | Out-Host

$labs | ForEach-Object { $_.Emails = $_.Emails.Split(';')
    $_.LinuxRdp = [System.Convert]::ToBoolean($_.LinuxRdp)
    $_.SharedPassword = [System.Convert]::ToBoolean($_.SharedPassword)
}

# Needs to create resources in this order, aka parallelize in these three groups, otherwise we get contentions:
# i.e. different jobs trying to create the same common resource (RG or lab account)
New-ResourceGroups -ConfigObject $labs
New-Accounts -ConfigObject $labs
New-AzLabMultiple -ConfigObject $labs
