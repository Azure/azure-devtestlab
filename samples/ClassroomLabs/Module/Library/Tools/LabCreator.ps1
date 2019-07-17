# TODO: support shared images

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
        
        $modulePath = Join-Path $path '..' 'Az.AzureLabs.psm1'
        Import-Module $modulePath

        New-AzLabAccount -ResourceGroupName $ResourceGroupName -LabAccountName $LabAccountName | Out-Null
        Write-Host "$LabAccountName lab account created or found."
    }
    
    $jobs = @()
    $lacs | ForEach-Object {
        $jobs += Start-Job -ScriptBlock $block -ArgumentList $PSScriptRoot, $_.ResourceGroupName, $_.LabAccountName -Name $_.LabAccountName
    }

    $hours = 1
    Wait-JobWithProgress -jobs $jobs -secTimeout (60 * 60 * $hours)
}

function Show-JobProgress {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory, ValueFromPipeline)]
        [ValidateNotNullOrEmpty()]
        [System.Management.Automation.Job[]]
        $Job
        ,
        [Parameter()]
        [ValidateNotNullOrEmpty()]
        [scriptblock]
        $FilterScript
    )
  
    Process {
        # if you have 'strict' mode on, you can't check for the existence of a property
        # by using the dot notation, because it triggers a 'property don't exist exception'
        if (-not ("ChildJobs" -in $job.PSobject.Properties.Name)) {
            Write-Host "No Childjobs for this job ..."
            return
        }
        $Job.ChildJobs | ForEach-Object {
            if (-not $_.Progress) {
                return
            }
  
            $LastProgress = $_.Progress
            if ($FilterScript) {
                $LastProgress = $LastProgress | Where-Object -FilterScript $FilterScript
            }
  
            $LastProgress | Group-Object -Property Activity, StatusDescription | ForEach-Object {
                $_.Group | Select-Object -Last 1
  
            } | ForEach-Object {
                $ProgressParams = @{ }
                if ($_.Activity -and $_.Activity -ne $null) { $ProgressParams.Add('Activity', $_.Activity) }
                if ($_.StatusDescription -and $_.StatusDescription -ne $null) { $ProgressParams.Add('Status', $_.StatusDescription) }
                if ($_.CurrentOperation -and $_.CurrentOperation -ne $null) { $ProgressParams.Add('CurrentOperation', $_.CurrentOperation) }
                if ($_.ActivityId -and $_.ActivityId -gt -1) { $ProgressParams.Add('Id', $_.ActivityId) }
                if ($_.ParentActivityId -and $_.ParentActivityId -gt -1) { $ProgressParams.Add('ParentId', $_.ParentActivityId) }
                if ($_.PercentComplete -and $_.PercentComplete -gt -1) { $ProgressParams.Add('PercentComplete', $_.PercentComplete) }
                if ($_.SecondsRemaining -and $_.SecondsRemaining -gt -1) { $ProgressParams.Add('SecondsRemaining', $_.SecondsRemaining) }
  
                Write-Progress @ProgressParams
            }
        }
    }
}
  
function Wait-JobWithProgress {
    param(
        [ValidateNotNullOrEmpty()]
        $jobs,
  
        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        $secTimeout
    )
  
    Write-Host "Waiting for results at most $secTimeout seconds, or $( [math]::Round($secTimeout / 60,1)) minutes, or $( [math]::Round($secTimeout / 60 / 60,1)) hours ..."
  
    if (-not $jobs) {
        Write-Host "No jobs to wait for"
        return
    }
  
    # Control how often we show output and print out time passed info
    # Change here to make it go faster or slower
    $RetryIntervalSec = 7
    $MaxPrintInterval = 7
    $PrintInterval = 1
  
    $timer = [Diagnostics.Stopwatch]::StartNew()
  
    $runningJobs = $jobs | Where-Object { $_ -and ($_.State -eq "Running") }
    while (($runningJobs) -and ($timer.Elapsed.TotalSeconds -lt $secTimeout)) {
  
        $runningJobs | Receive-job -Keep -ErrorAction Continue                # Show partial results
        $runningJobs | Wait-Job -Timeout $RetryIntervalSec | Show-JobProgress # Show progress bar
  
        if ($PrintInterval -ge $MaxPrintInterval) {
            $totalSecs = [math]::Round($timer.Elapsed.TotalSeconds, 0)
            Write-Host "Passed: $totalSecs seconds, or $( [math]::Round($totalSecs / 60,1)) minutes, or $( [math]::Round($totalSecs / 60 / 60,1)) hours ..." -ForegroundColor Yellow
            $PrintInterval = 1
        }
        else {
            $PrintInterval += 1
        }
  
        $runningJobs = $jobs | Where-Object { $_ -and ($_.State -eq "Running") }
    }
  
    $timer.Stop()
    $lasted = $timer.Elapsed.TotalSeconds
  
    Write-Host ""
    Write-Host "JOBS STATUS"
    Write-Host "-------------------"
    $jobs                                           # Show overall status of all jobs
    Write-Host ""
    Write-Host "JOBS OUTPUT"
    Write-Host "-------------------"
    $jobs | Receive-Job -ErrorAction Continue       # Show output for all jobs
  
    $jobs | Remove-job -Force                       # -Force removes also the ones still running ...
  
    if ($lasted -gt $secTimeout) {
        throw "Jobs did not complete before timeout period. It lasted $lasted secs."
    }
    else {
        Write-Host "Jobs completed before timeout period. It lasted $lasted secs."
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

    Write-Host "Starting creation of all labs in parallel."

    $jobs = $ConfigObject | ForEach-Object {
        Start-Job  -InitializationScript $init -ScriptBlock $block -ArgumentList $PSScriptRoot -InputObject $_ -Name $_.LabName
    }

    $hours = 2
    Wait-JobWithProgress -jobs $jobs -secTimeout (60 * 60 * $hours)
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
