[CmdletBinding()]
param(
    [parameter(Mandatory = $true, ValueFromPipelineByPropertyName = $true)]
    [string]
    $CsvConfigFile
)

Import-Module ../Az.LabServices.psm1 -Force

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

        Write-Host "Start creation of $LabName"

        $la = Get-AzLabAccount -ResourceGroupName $ResourceGroupName -LabAccountName $LabAccountName

        $lab = $la | Get-AzLab -LabName $LabName

        if ($lab) {
            # TODO: cannot set max users
            $lab = $lab | Set-AzLab -UsageQuotaInHours $usageQuota -UserAccessMode $UsageMode  -SharedPasswordEnabled:$SharedPassword
            Write-Host "$LabName lab already exist. Republished."
        }
        else {
            # Try to load shared image and then gallery image
            $img = $la | Get-AzLabAccountSharedImage | Where-Object { $_.name -like $ImageName }
            if(-not $img) {
                $img = $la | Get-AzLabAccountGalleryImage | Where-Object { $_.name -like $ImageName }
                if (-not $img -or $img.Count -ne 1) { Write-Error "$ImageName pattern doesn't match just one gallery image." }
            }
            Write-Host "Image $ImageName found."
    
            #TODO: cannot set maxUsers
            $lab = $la `
            | New-AzLab -LabName $LabName -Image $img -Size $size -UserName $userName -Password $password -LinuxRdpEnabled:$linuxRdp `
            | Publish-AzLab `
            | Set-AzLab -UsageQuotaInHours $usageQuota -UserAccessMode $UsageMode  -SharedPasswordEnabled:$SharedPassword `

            Write-Host "$LabName lab doesn't exist. Created it."
        }

        $lab = $lab | Add-AzLabUser -Emails $emails
        $users = $lab | Get-AzLabUser
        $users | ForEach-Object { $lab | Send-AzLabUserInvitationEmail -User $_ -InvitationText $invitation } | Out-Null
        Write-Host "Added Users: $emails."

        if ($Schedules) {
            $Schedules | ForEach-Object { $_ | New-AzLabSchedule -Lab $lab } | Out-Null
            Write-Host "Added all schedules."
        }
    }
}

# No need to parallelize this one as super fast
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

    $block = {
        param($path, $ResourceGroupName, $LabAccountName)

        Set-StrictMode -Version Latest
        $ErrorActionPreference = 'Stop'
        
        $modulePath = Join-Path $path '..' 'Az.LabServices.psm1'
        Import-Module $modulePath

        New-AzLabAccount -ResourceGroupName $ResourceGroupName -LabAccountName $LabAccountName | Out-Null
        Write-Host "$LabAccountName lab account created or found."
    }
    
    Write-Host "Starting lab accounts creation in parallel. Can take a while."
    $jobs = @()
    $lacs | ForEach-Object {
        $jobs += Start-Job -ScriptBlock $block -ArgumentList $PSScriptRoot, $_.ResourceGroupName, $_.LabAccountName -Name $_.LabAccountName
    }

    $hours = 1
    $jobs | Wait-Job -Timeout (60 * 60 * $hours) | Receive-Job
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
        
        $modulePath = Join-Path $path '..' 'Az.LabServices.psm1'
        Import-Module $modulePath
        # Really?? It got to be the lines below? Doing a ForEach doesn't work ...
        $input.movenext() | Out-Null
        $obj = $input.current[0]
        Write-Verbose "object inside the newazmultiple block $obj"
        $obj | New-AzLabSingle
    }

    Write-Host "Starting creation of all labs in parallel. Can take a while."

    $jobs = $ConfigObject | ForEach-Object {
        Write-Verbose "From config: $_"
        Start-Job  -InitializationScript $init -ScriptBlock $block -ArgumentList $PSScriptRoot -InputObject $_ -Name $_.LabName
    }

    $hours = 2
    $jobs | Wait-Job -Timeout (60 * 60 * $hours) | Receive-Job
}

function Import-Schedules {
    param($schedules)

    $file = "./$schedules.csv"

    $scheds = Import-Csv $file
    $scheds | Foreach-Object {
        $_.WeekDays = ($_.WeekDays.Split(',')).Trim()
    }
    return $scheds
}

$labs = Import-Csv -Path $CsvConfigFile

Write-Verbose ($labs | Format-Table | Out-String)

$labs | ForEach-Object {
    $_.Emails = ($_.Emails.Split(';')).Trim()
    $_.LinuxRdp = [System.Convert]::ToBoolean($_.LinuxRdp)
    $_.SharedPassword = [System.Convert]::ToBoolean($_.SharedPassword)
    if ($_.Schedules) {
        Write-Host "Setting schedules for $($_.LabName)"
        $_.Schedules = Import-Schedules -schedules $_.Schedules
    }
}

Write-Verbose ($labs | ConvertTo-Json -Depth 10 | Out-String)

# Needs to create resources in this order, aka parallelize in these three groups, otherwise we get contentions:
# i.e. different jobs trying to create the same common resource (RG or lab account)
New-ResourceGroups  -ConfigObject $labs
New-Accounts        -ConfigObject $labs
New-AzLabMultiple   -ConfigObject $labs
