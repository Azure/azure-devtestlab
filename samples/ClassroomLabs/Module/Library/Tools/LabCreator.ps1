[CmdletBinding()]
param(
    [parameter(Mandatory = $true, ValueFromPipelineByPropertyName = $true)]
    [string]
    $CsvConfigFile
)

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
        Write-Host "Using RG Name $ResourceGroupName"
        if (-not (Get-AzResourceGroup -ResourceGroupName $ResourceGroupName -EA SilentlyContinue)) {
            New-AzResourceGroup -ResourceGroupName $ResourceGroupName -Location $Location | Out-null
            Write-Host "$ResourceGroupName resource group didn't exist. Created it."
        }

        $la = New-AzLabAccount -ResourceGroupName $ResourceGroupName -LabAccountName $LabAccountName
        Write-Host "$LabAccountName lab account created or found."

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
        Write-Host $modulePath
        Write-Host $Input.LabName
        # Really?? It got to be the lines below? Doing a ForEach doesn't work ...
        $input.movenext()
        $obj = $input.current[0]
        $obj | New-AzLabSingle
    }

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

New-AzLabMultiple -ConfigObject $labs
